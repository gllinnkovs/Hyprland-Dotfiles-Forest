#!/usr/bin/env bash
# Установка dotfiles Hyprland — LordWerdes
set -euo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/dotfiles-backup-$STAMP"
DIRS=(hypr waybar wofi)
DEPS=(hyprland waybar wofi kitty grim slurp wl-clipboard python python-gobject gtk3
      ttf-jetbrains-mono-nerd hyprpaper pipewire wireplumber libpulse
      networkmanager pavucontrol thunar xdg-desktop-portal-hyprland)

YES=0
NO_DEPS=0
NO_RELOAD=0

c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Установка Hyprland dotfiles

  ./install.sh [--yes] [--no-deps] [--no-reload]

  -y, --yes       не задавать вопросов
      --no-deps   не проверять/не ставить пакеты
      --no-reload не перезагружать Hyprland и Waybar
  -h, --help      эта справка
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-deps) NO_DEPS=1 ;;
        --no-reload) NO_RELOAD=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Неизвестный аргумент: $arg" ;;
    esac
done

ask() {
    [ "$YES" -eq 1 ] && return 0
    local answer
    read -r -p "$1 [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[YyДд] ]]
}

[ "$(id -u)" -eq 0 ] && die "Не запускай install.sh от root — скрипт ставит конфиги в \$HOME."
[ -d "$SRC/config/hypr" ] || die "Не найден каталог config/. Запусти скрипт из папки dotfiles."

info "Проверяю зависимости"

if [ "$NO_DEPS" -eq 0 ] && command -v pacman >/dev/null 2>&1; then
    missing=()
    for pkg in "${DEPS[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        warn "Не хватает пакетов: ${missing[*]}"
        if ask "Установить их через pacman?"; then
            sudo pacman -S --needed --noconfirm "${missing[@]}"
        else
            warn "Пропускаю установку пакетов — часть функций может не работать."
        fi
    else
        info "Все пакеты на месте"
    fi

    # На случай, если pacman что-то не поставил (или пакет переименован)
    for cmd in hyprctl waybar wofi kitty grim slurp wl-copy python3 wpctl pactl; do
        command -v "$cmd" >/dev/null 2>&1 || warn "Команда '$cmd' не найдена — проверь пакеты вручную"
    done
fi

mkdir -p "$BACKUP"
: >"$BACKUP/manifest"

info "Делаю бэкап текущих конфигов → $BACKUP"
for dir in "${DIRS[@]}"; do
    if [ -e "$TARGET/$dir" ]; then
        cp -a "$TARGET/$dir" "$BACKUP/"
        echo "$dir" >>"$BACKUP/manifest"
        printf '    ~/.config/%s\n' "$dir"
    fi
done

info "Копирую конфиги"
for dir in "${DIRS[@]}"; do
    rm -rf "$TARGET/$dir"
    cp -a "$SRC/config/$dir" "$TARGET/$dir"
done

chmod +x "$TARGET/hypr/wofi.sh" \
         "$TARGET/hypr/bindhelp.py" \
         "$TARGET/waybar/scripts/volume.py" \
         "$TARGET/waybar/scripts/volume-print.sh"

if [ "$NO_RELOAD" -eq 0 ]; then
    if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        info "Перезагружаю Hyprland"
        hyprctl reload >/dev/null 2>&1 || true

        info "Перезапускаю Waybar и демон громкости"
        pkill -x waybar >/dev/null 2>&1 || true
        sleep 0.4
        setsid -f waybar >/dev/null 2>&1 || true

        pkill -f "[v]olume.py" >/dev/null 2>&1 || true
        sleep 0.2
        setsid -f "$TARGET/waybar/scripts/volume.py" --daemon >/dev/null 2>&1 || true

        if command -v hyprpaper >/dev/null 2>&1; then
            info "Перезапускаю hyprpaper (обои)"
            pkill -x hyprpaper >/dev/null 2>&1 || true
            sleep 0.3
            setsid -f hyprpaper >/dev/null 2>&1 || true
        fi

        errors="$(hyprctl configerrors 2>/dev/null || true)"
        if [ -n "$errors" ]; then
            warn "Hyprland сообщает об ошибках:"
            printf '%s\n' "$errors"
        fi
    else
        warn "Hyprland не запущен — пропускаю reload."
    fi
fi

echo
info "Готово!"
cat <<EOF

  Конфиги:   ~/.config/hypr, ~/.config/waybar, ~/.config/wofi
  Бэкап:     $BACKUP
  Откат:     ./uninstall.sh

  Основное:
    Super + Enter   терминал
    Super + D       лаунчер / закрыть лаунчер
    Super + H       шпаргалка по биндам
    Print           скриншот области в буфер
    Super + Print   весь экран в ~/Pictures

  YouTube: https://www.youtube.com/@LordWerdes
  Telegram: https://t.me/lordwerdes1337
EOF
