#!/usr/bin/env bash
# Удаление dotfiles Hyprland — LordWerdes
set -euo pipefail

TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
DIRS=(hypr waybar wofi)

YES=0
NO_RELOAD=0

c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Удаление Hyprland dotfiles

  ./uninstall.sh [--yes] [--no-reload]

  -y, --yes       не задавать вопросов
      --no-reload не перезагружать Hyprland и не запускать Waybar
  -h, --help      эта справка

Скрипт ищет последний бэкап ~/.config/dotfiles-backup-* и
восстанавливает из него hypr, waybar и wofi.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-reload) NO_RELOAD=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Неизвестный аргумент: $arg" ;;
    esac
done

ask() {
    [ "$YES" -eq 1 ] && return 0
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "$answer" =~ ^[YyДд] ]]
}

[ "$(id -u)" -eq 0 ] && die "Не запускай uninstall.sh от root — скрипт работает с \$HOME."

info "Останавливаю Waybar, демон громкости и шпаргалку"
pkill -x waybar >/dev/null 2>&1 || true
pkill -f "[v]olume.py" >/dev/null 2>&1 || true
if [ -f "${XDG_RUNTIME_DIR:-/tmp}/bindhelp.pid" ]; then
    pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/bindhelp.pid" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null \
        && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "bindhelp.py"; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/bindhelp.pid"
fi

BACKUP="$(ls -1d "$TARGET"/dotfiles-backup-* 2>/dev/null | sort | tail -n 1 || true)"

backed_up() {
    [ -f "$BACKUP/manifest" ] && grep -qx "$1" "$BACKUP/manifest"
}

restore() {
    local dir="$1"
    if [ -e "$BACKUP/$dir" ]; then
        rm -rf "$TARGET/$dir"
        cp -a "$BACKUP/$dir" "$TARGET/$dir"
        printf '    восстановлен ~/.config/%s\n' "$dir"
    elif [ -f "$BACKUP/manifest" ] && ! backed_up "$dir"; then
        # конфига не было до установки — убираем поставленный
        rm -rf "$TARGET/$dir"
        printf '    удалён ~/.config/%s (его не было до установки)\n' "$dir"
    fi
}

if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
    info "Найден бэкап: $BACKUP"
    if ask "Восстановить конфиги из него?"; then
        for dir in "${DIRS[@]}"; do
            restore "$dir"
        done
        info "Конфиги восстановлены"
    else
        info "Отмена — ничего не изменено."
        exit 0
    fi
else
    warn "Бэкап не найден."
    if ! ask "Удалить установленные конфиги (~/.config/hypr, waybar, wofi)?"; then
        info "Отмена — ничего не изменено."
        exit 0
    fi
    for dir in "${DIRS[@]}"; do
        if [ -e "$TARGET/$dir" ]; then
            rm -rf "$TARGET/$dir"
            printf '    удалён ~/.config/%s\n' "$dir"
        fi
    done
fi

if [ "$NO_RELOAD" -eq 0 ] && command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    info "Перезагружаю Hyprland"
    hyprctl reload >/dev/null 2>&1 || true
    errors="$(hyprctl configerrors 2>/dev/null || true)"
    if [ -n "$errors" ]; then
        warn "Hyprland сообщает об ошибках:"
        printf '%s\n' "$errors"
    fi
    info "Запускаю Waybar, если он был установлен"
    if command -v waybar >/dev/null 2>&1 && [ -d "$TARGET/waybar" ]; then
        pkill -x waybar >/dev/null 2>&1 || true
        sleep 0.4
        setsid -f waybar >/dev/null 2>&1 || true
    fi
fi

echo
info "Готово!"
if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
    cat <<EOF

  Бэкап сохранён: $BACKUP
  Его можно удалить вручную, когда убедишься, что всё в порядке.
EOF
fi
