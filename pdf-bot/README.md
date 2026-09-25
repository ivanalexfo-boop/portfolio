# PDF-бот для Telegram

Бот принимает файлы и возвращает их в PDF.

- **Картинки** (JPG, PNG, WEBP, BMP, GIF, TIFF, фото): Pillow + img2pdf, страница A4
- **Документы, таблицы, презентации** (DOC/DOCX/ODT/RTF/TXT/HTML, XLS/XLSX/ODS/CSV, PPT/PPTX/ODP): LibreOffice в headless-режиме
- **/merge → картинки → /done**: собирает несколько картинок в один PDF

## Установка на VPS (Ubuntu/Debian) одной командой

Открой консоль сервера и вставь:

```bash
curl -fsSL https://raw.githubusercontent.com/ivanalexfo-boop/portfolio/refs/heads/claude/hello-jhiser/pdf-bot/install.sh | sudo bash
```

Скрипт поставит LibreOffice и Python, спросит токен, запустит бота как systemd-сервис
(он сам поднимается после перезагрузки). Повторный запуск той же команды обновляет бота.

- логи: `journalctl -u pdf-bot -f`
- перезапуск: `systemctl restart pdf-bot`
- сменить токен: отредактируй `/etc/pdf-bot.env` и перезапусти

## Запуск через Docker

```bash
cd pdf-bot
docker build -t pdf-bot .
docker run -d --restart=always -e BOT_TOKEN=<токен от @BotFather> pdf-bot
```

## Локальный запуск

Нужны Python 3.10+ и LibreOffice (`sudo apt install libreoffice` / `brew install --cask libreoffice`).

```bash
cd pdf-bot
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
BOT_TOKEN=<токен> python bot.py
```

## Настройки (переменные окружения)

| Переменная | По умолчанию | Описание |
|---|---|---|
| `BOT_TOKEN` | — | токен бота (обязательно) |
| `LIBREOFFICE_BIN` | ищется `soffice` в PATH | путь к LibreOffice |
| `OFFICE_TIMEOUT` | `120` | таймаут конвертации одного документа, сек |
| `OFFICE_CONCURRENCY` | `2` | сколько документов конвертировать одновременно |

Ограничение Telegram Bot API: бот может скачать файл размером до 20 МБ.
