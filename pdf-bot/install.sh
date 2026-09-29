#!/usr/bin/env bash
# Установка PDF-бота на чистый сервер Ubuntu/Debian.
# Запуск:
#   curl -fsSL https://raw.githubusercontent.com/ivanalexfo-boop/portfolio/refs/heads/claude/hello-jhiser/pdf-bot/install.sh | sudo bash
# Повторный запуск обновляет бота до свежей версии (токен спрашивается только в первый раз).
set -euo pipefail

REPO="https://github.com/ivanalexfo-boop/portfolio.git"
BRANCH="${BRANCH:-claude/hello-jhiser}"
APP_DIR="/opt/pdf-bot"
ENV_FILE="/etc/pdf-bot.env"
SERVICE="pdf-bot"
BOT_USER="pdfbot"

if [ "$(id -u)" -ne 0 ]; then
  echo "Запусти скрипт от root (через sudo)." >&2
  exit 1
fi

echo "==> Ставлю LibreOffice, Python и шрифты (пара минут)…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends \
  ca-certificates curl git python3 python3-venv \
  libreoffice-writer libreoffice-calc libreoffice-impress \
  fonts-dejavu fonts-liberation

if [ ! -s "$ENV_FILE" ]; then
  while true; do
    read -rp "Вставь токен бота от @BotFather: " TOKEN < /dev/tty
    TOKEN="$(echo "$TOKEN" | tr -d '[:space:]')"
    if curl -fsS "https://api.telegram.org/bot${TOKEN}/getMe" | grep -q '"ok":true'; then
      break
    fi
    echo "Токен не подошёл (или сервер не достучался до Telegram). Попробуй ещё раз."
  done
  install -m 600 /dev/null "$ENV_FILE"
  echo "BOT_TOKEN=${TOKEN}" > "$ENV_FILE"
fi

echo "==> Скачиваю код бота…"
id "$BOT_USER" >/dev/null 2>&1 || \
  useradd --system --create-home --home-dir /var/lib/pdfbot --shell /usr/sbin/nologin "$BOT_USER"

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
git clone -q --depth 1 --branch "$BRANCH" "$REPO" "$SRC"
mkdir -p "$APP_DIR"
cp "$SRC"/pdf-bot/*.py "$SRC"/pdf-bot/requirements.txt "$APP_DIR"/

echo "==> Ставлю зависимости Python…"
[ -x "$APP_DIR/venv/bin/python" ] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/requirements.txt"

echo "==> Настраиваю автозапуск…"
cat > "/etc/systemd/system/${SERVICE}.service" <<EOF
[Unit]
Description=Telegram PDF bot
After=network-online.target
Wants=network-online.target

[Service]
User=${BOT_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${APP_DIR}/venv/bin/python bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1
systemctl restart "$SERVICE"
sleep 3

if systemctl is-active --quiet "$SERVICE"; then
  echo
  echo "✅ Готово! Бот запущен. Напиши ему /start в Telegram."
  echo "   Логи:        journalctl -u ${SERVICE} -f"
  echo "   Перезапуск:  systemctl restart ${SERVICE}"
else
  echo "❌ Бот не запустился. Последние строки лога:" >&2
  journalctl -u "$SERVICE" -n 30 --no-pager >&2
  exit 1
fi
