"""Telegram-бот, который конвертирует присланные файлы в PDF."""
import asyncio
import logging
import os
import tempfile
from pathlib import Path

from aiogram import Bot, Dispatcher, F, Router
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import FSInputFile, Message

from converter import IMAGE_EXT, SUPPORTED_EXT, ConversionError, convert_to_pdf, images_to_pdf

# Bot API не отдаёт ботам файлы больше 20 МБ
MAX_FILE_SIZE = 20 * 1024 * 1024
MAX_MERGE_IMAGES = 50

router = Router()

HELP_TEXT = (
    "Пришли файл — верну PDF.\n\n"
    "<b>Поддерживается:</b>\n"
    "• Картинки: JPG, PNG, WEBP, BMP, GIF, TIFF (и обычные фото)\n"
    "• Документы: DOC, DOCX, ODT, RTF, TXT, HTML\n"
    "• Таблицы: XLS, XLSX, ODS, CSV\n"
    "• Презентации: PPT, PPTX, ODP\n\n"
    "<b>Несколько картинок в один PDF:</b>\n"
    "/merge — начать сбор, затем присылай картинки\n"
    "/done — собрать PDF\n"
    "/cancel — отменить\n\n"
    "Ограничение Telegram: файл до 20 МБ."
)


class Merge(StatesGroup):
    collecting = State()


@router.message(CommandStart())
@router.message(Command("help"))
async def cmd_start(message: Message) -> None:
    await message.answer(HELP_TEXT)


@router.message(Command("merge"))
async def cmd_merge(message: Message, state: FSMContext) -> None:
    await state.set_state(Merge.collecting)
    await state.update_data(images=[])
    await message.answer("Присылай картинки по одной или альбомом. Когда закончишь — /done, отмена — /cancel.")


@router.message(Command("cancel"))
async def cmd_cancel(message: Message, state: FSMContext) -> None:
    await state.clear()
    await message.answer("Отменено.")


@router.message(Merge.collecting, Command("done"))
async def cmd_done(message: Message, state: FSMContext, bot: Bot) -> None:
    images: list[dict] = (await state.get_data()).get("images", [])
    await state.clear()
    if not images:
        await message.answer("Ты не прислал ни одной картинки.")
        return

    status = await message.answer(f"⏳ Собираю PDF из {len(images)} изображений…")
    with tempfile.TemporaryDirectory(prefix="pdfbot-") as tmp:
        tmp_dir = Path(tmp)
        paths = []
        for i, img in enumerate(images):
            path = tmp_dir / f"{i:03d}{img['ext']}"
            await bot.download(img["file_id"], destination=path)
            paths.append(path)
        try:
            pdf = await images_to_pdf(paths, tmp_dir / "merged.pdf")
        except ConversionError as e:
            await status.edit_text(f"❌ Ошибка: {e}")
            return
        await message.answer_document(FSInputFile(pdf, filename="merged.pdf"))
    await status.delete()


@router.message(Command("done"))
async def cmd_done_outside(message: Message) -> None:
    await message.answer("Сначала начни сбор командой /merge.")


def _image_from_message(message: Message) -> dict | None:
    """Возвращает {file_id, ext}, если в сообщении картинка."""
    if message.photo:
        return {"file_id": message.photo[-1].file_id, "ext": ".jpg"}
    if message.document:
        ext = Path(message.document.file_name or "").suffix.lower()
        if ext in IMAGE_EXT:
            return {"file_id": message.document.file_id, "ext": ext}
    return None


@router.message(Merge.collecting, F.photo | F.document)
async def collect_image(message: Message, state: FSMContext) -> None:
    image = _image_from_message(message)
    if image is None:
        await message.answer("В режиме /merge принимаются только картинки. /done — собрать, /cancel — отменить.")
        return
    data = await state.get_data()
    images = data.get("images", [])
    if len(images) >= MAX_MERGE_IMAGES:
        await message.answer(f"Максимум {MAX_MERGE_IMAGES} картинок. Жми /done.")
        return
    images.append(image)
    await state.update_data(images=images)
    # у альбома не отвечаем на каждое фото, чтобы не спамить
    if not message.media_group_id:
        await message.answer(f"Добавлено: {len(images)}. Ещё картинки или /done.")


@router.message(F.photo)
async def handle_photo(message: Message, bot: Bot) -> None:
    await _convert_and_reply(message, bot, message.photo[-1].file_id, f"photo_{message.message_id}.jpg")


@router.message(F.document)
async def handle_document(message: Message, bot: Bot) -> None:
    doc = message.document
    name = doc.file_name or f"file_{message.message_id}"
    ext = Path(name).suffix.lower()

    if ext not in SUPPORTED_EXT:
        await message.answer(f"Формат {ext or 'без расширения'} не поддерживается. /help — список форматов.")
        return
    if ext == ".pdf":
        await message.answer("Это уже PDF 🙂")
        return
    if doc.file_size and doc.file_size > MAX_FILE_SIZE:
        await message.answer("Файл больше 20 МБ — Telegram не даёт ботам скачивать такие файлы.")
        return

    await _convert_and_reply(message, bot, doc.file_id, name)


async def _convert_and_reply(message: Message, bot: Bot, file_id: str, file_name: str) -> None:
    status = await message.answer("⏳ Конвертирую…")
    with tempfile.TemporaryDirectory(prefix="pdfbot-") as tmp:
        tmp_dir = Path(tmp)
        # имя из Telegram может содержать что угодно — берём только базовое имя
        src = tmp_dir / Path(file_name).name
        try:
            await bot.download(file_id, destination=src)
            pdf = await convert_to_pdf(src, tmp_dir)
        except ConversionError as e:
            await status.edit_text(f"❌ Ошибка: {e}")
            return
        except Exception:
            logging.exception("conversion failed for %s", file_name)
            await status.edit_text("❌ Что-то пошло не так. Попробуй другой файл.")
            return
        await message.answer_document(FSInputFile(pdf, filename=Path(file_name).stem + ".pdf"))
    await status.delete()


@router.message()
async def fallback(message: Message) -> None:
    await message.answer("Пришли файл или фото — я сделаю из него PDF. /help — подробнее.")


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    token = os.getenv("BOT_TOKEN")
    if not token:
        raise SystemExit("Не задан BOT_TOKEN")

    bot = Bot(token, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
    dp = Dispatcher()
    dp.include_router(router)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
