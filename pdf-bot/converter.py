"""Конвертация файлов в PDF: картинки через Pillow + img2pdf, документы через LibreOffice."""
import asyncio
import io
import os
import shutil
import tempfile
from pathlib import Path

import img2pdf
from PIL import Image, ImageOps

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff"}
OFFICE_EXT = {
    ".doc", ".docx", ".odt", ".rtf", ".txt",
    ".xls", ".xlsx", ".ods", ".csv",
    ".ppt", ".pptx", ".odp",
    ".html", ".htm",
}
SUPPORTED_EXT = IMAGE_EXT | OFFICE_EXT | {".pdf"}

LIBREOFFICE = os.getenv("LIBREOFFICE_BIN") or shutil.which("soffice") or shutil.which("libreoffice")
OFFICE_TIMEOUT = int(os.getenv("OFFICE_TIMEOUT", "120"))
# LibreOffice тяжёлый — не запускаем больше N конвертаций одновременно
_office_semaphore = asyncio.Semaphore(int(os.getenv("OFFICE_CONCURRENCY", "2")))

A4 = (img2pdf.mm_to_pt(210), img2pdf.mm_to_pt(297))


class ConversionError(Exception):
    pass


def _normalize_image(path: Path) -> bytes:
    """Приводит картинку к формату, который img2pdf примет без ошибок."""
    with Image.open(path) as img:
        img = ImageOps.exif_transpose(img)
        if img.mode in ("RGBA", "LA", "P"):
            img = img.convert("RGBA")
            background = Image.new("RGB", img.size, "white")
            background.paste(img, mask=img.getchannel("A"))
            img = background
        elif img.mode != "RGB":
            img = img.convert("RGB")
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=92)
        return buf.getvalue()


def _images_to_pdf_sync(paths: list[Path], out: Path) -> None:
    try:
        images = [_normalize_image(p) for p in paths]
    except Exception as e:
        raise ConversionError(f"не удалось открыть изображение: {e}") from e
    layout = img2pdf.get_layout_fun(A4, fit=img2pdf.FitMode.into, auto_orient=True)
    out.write_bytes(img2pdf.convert(images, layout_fun=layout))


async def images_to_pdf(paths: list[Path], out: Path) -> Path:
    await asyncio.to_thread(_images_to_pdf_sync, paths, out)
    return out


async def office_to_pdf(src: Path, out_dir: Path) -> Path:
    if not LIBREOFFICE:
        raise ConversionError("LibreOffice не установлен на сервере")

    async with _office_semaphore:
        # отдельный профиль на каждый запуск, иначе параллельные soffice мешают друг другу
        with tempfile.TemporaryDirectory(prefix="lo-profile-") as profile:
            proc = await asyncio.create_subprocess_exec(
                LIBREOFFICE,
                f"-env:UserInstallation=file://{profile}",
                "--headless", "--norestore",
                "--convert-to", "pdf",
                "--outdir", str(out_dir),
                str(src),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                _, stderr = await asyncio.wait_for(proc.communicate(), OFFICE_TIMEOUT)
            except asyncio.TimeoutError:
                proc.kill()
                await proc.wait()
                raise ConversionError("конвертация заняла слишком много времени")

    result = out_dir / (src.stem + ".pdf")
    if proc.returncode != 0 or not result.exists():
        raise ConversionError(f"LibreOffice не смог обработать файл: {stderr.decode(errors='ignore').strip()}")
    return result


async def convert_to_pdf(src: Path, out_dir: Path) -> Path:
    """Конвертирует один файл в PDF и возвращает путь к результату."""
    ext = src.suffix.lower()
    if ext == ".pdf":
        return src
    if ext in IMAGE_EXT:
        return await images_to_pdf([src], out_dir / (src.stem + ".pdf"))
    if ext in OFFICE_EXT:
        return await office_to_pdf(src, out_dir)
    raise ConversionError(f"формат {ext or 'без расширения'} не поддерживается")
