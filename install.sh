#!/usr/bin/env bash
# Установка Hyprland dotfiles — LordWerdes
# Arch Linux и производные: CachyOS, EndeavourOS, Manjaro, Garuda и т.д.
set -euo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S-%N)"
BACKUP="$TARGET/dotfiles-backup-$STAMP"
DIRS=(hypr waybar wofi kitty)
DEPS=(hyprland waybar wofi kitty grim slurp wl-clipboard python python-gobject gtk3
      ttf-hack ttf-jetbrains-mono-nerd hyprpaper pipewire wireplumber libpulse
      networkmanager pavucontrol thunar brightnessctl playerctl
      xdg-desktop-portal-hyprland)

YES=0
NO_DEPS=0
NO_RELOAD=0
KEEP_LOCAL=0

c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Установка Hyprland dotfiles

  ./install.sh [--yes] [--no-deps] [--no-reload] [--keep-local]

  -y, --yes        не задавать вопросов
      --no-deps    не проверять/не ставить пакеты
      --no-reload  не перезагружать Hyprland и Waybar
      --keep-local не перезаписывать ~/.config/hypr/local.lua
  -h, --help       эта справка
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --no-deps) NO_DEPS=1 ;;
        --no-reload) NO_RELOAD=1 ;;
        --keep-local) KEEP_LOCAL=1 ;;
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

DISTRO="Arch Linux"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="${PRETTY_NAME:-${NAME:-Arch Linux}}"
fi

info "Дистрибутив: $DISTRO"

PRIV=()
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        PRIV=(sudo)
    elif command -v doas >/dev/null 2>&1; then
        PRIV=(doas)
    else
        die "Нужен sudo или doas для установки пакетов (или запусти с --no-deps)."
    fi
fi

detect_gpu() {
    local card vendor boot primary="" fallback=""
    for card in /sys/class/drm/card[0-9]*; do
        [ -r "$card/device/vendor" ] || continue
        vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
        case "$vendor" in
            0x10de) fallback="nvidia" ;;
            0x1002) [ -n "$fallback" ] || fallback="amd" ;;
            0x8086) [ -n "$fallback" ] || fallback="intel" ;;
            *) continue ;;
        esac
        boot="$(cat "$card/device/boot_vga" 2>/dev/null || echo 0)"
        if [ "$boot" = "1" ]; then
            case "$vendor" in
                0x10de) primary="nvidia" ;;
                0x1002) primary="amd" ;;
                0x8086) primary="intel" ;;
            esac
            break
        fi
    done
    printf '%s' "${primary:-$fallback}"
}

GPU="$(detect_gpu)"
info "GPU: ${GPU:-не определён}"

info "Проверяю зависимости"

if [ "$NO_DEPS" -eq 0 ]; then
    if command -v pacman >/dev/null 2>&1; then
        missing=()
        for pkg in "${DEPS[@]}"; do
            # -T учитывает provides: не поставит дубль, если уже есть hyprland-git и т.п.
            pacman -T "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
        done

        if [ "${#missing[@]}" -gt 0 ]; then
            warn "Не хватает пакетов: ${missing[*]}"
            if ask "Установить их через pacman?"; then
                if ! "${PRIV[@]}" pacman -S --needed --noconfirm "${missing[@]}"; then
                    warn "Не удалось поставить всё сразу — пробую по одному."
                    for pkg in "${missing[@]}"; do
                        "${PRIV[@]}" pacman -S --needed --noconfirm "$pkg" \
                            || warn "Не удалось установить: $pkg"
                    done
                fi
            else
                warn "Пропускаю установку пакетов — часть функций может не работать."
            fi
        else
            info "Все пакеты на месте"
        fi

        # На случай, если pacman что-то не поставил (или пакет переименован)
        for cmd in hyprctl waybar wofi kitty grim slurp wl-copy python3 wpctl pactl brightnessctl; do
            command -v "$cmd" >/dev/null 2>&1 || warn "Команда '$cmd' не найдена — проверь пакеты вручную"
        done
    else
        warn "pacman не найден — это не Arch-based система."
        warn "Поставь пакеты вручную: ${DEPS[*]}"
    fi
fi

# Lua-конфиг требует Hyprland 0.57+
if command -v hyprctl >/dev/null 2>&1; then
    VER="$(hyprctl version 2>/dev/null | awk '/^Hyprland /{print $2; exit}' || true)"
    if [ -n "$VER" ]; then
        MAJOR="${VER%%.*}"
        REST="${VER#*.}"
        MINOR="${REST%%.*}"
        if [ "$MAJOR" -eq 0 ] 2>/dev/null && [ "$MINOR" -lt 57 ] 2>/dev/null; then
            warn "Hyprland $VER: для Lua-конфига нужна версия 0.57 или новее."
        fi
    fi
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

LOCAL_TMP=""
if [ "$KEEP_LOCAL" -eq 1 ] && [ -f "$TARGET/hypr/local.lua" ]; then
    LOCAL_TMP="$(mktemp)"
    cp "$TARGET/hypr/local.lua" "$LOCAL_TMP"
fi

info "Копирую конфиги"
for dir in "${DIRS[@]}"; do
    rm -rf "$TARGET/$dir"
    cp -a "$SRC/config/$dir" "$TARGET/$dir"
done

write_local() {
    local file="$TARGET/hypr/local.lua"
    {
        printf '%s\n' "-- Сгенерировано install.sh $(date +%Y-%m-%d)."
        printf '%s\n' "-- GPU: ${GPU:-unknown}. При следующей установке файл перезапишется"
        printf '%s\n' "-- (если не запускать install.sh с --keep-local)."
        case "$GPU" in
            nvidia)
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "nvidia")'
                printf '%s\n' 'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")'
                printf '%s\n' 'hl.env("NVD_BACKEND", "direct")'
                printf '%s\n' 'hl.env("GBM_BACKEND", "nvidia-drm")'
                printf '%s\n' 'hl.config({ cursor = { no_hardware_cursors = true } })'
                ;;
            amd)
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "radeonsi")'
                ;;
            intel)
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "iHD")'
                ;;
            *)
                printf '%s\n' '-- GPU не определён: стандартные настройки.'
                ;;
        esac
        if [ -d "$HOME/.icons/Bibata-Mint" ] \
            || [ -d "$HOME/.local/share/icons/Bibata-Mint" ] \
            || [ -d "/usr/share/icons/Bibata-Mint" ]; then
            printf '%s\n' 'hl.env("XCURSOR_THEME", "Bibata-Mint")'
        fi
    } >"$file"
}

if [ -n "$LOCAL_TMP" ]; then
    cp "$LOCAL_TMP" "$TARGET/hypr/local.lua"
    rm -f "$LOCAL_TMP"
    info "local.lua сохранён (--keep-local)"
else
    write_local
fi

chmod +x "$TARGET/hypr/wofi.sh" \
         "$TARGET/hypr/bindhelp.py" \
         "$TARGET/waybar/scripts/volume.py" \
         "$TARGET/waybar/scripts/volume-print.sh"

# Метка: uninstall по ней понимает, какие каталоги создал именно этот установщик
for dir in "${DIRS[@]}"; do
    : >"$TARGET/$dir/.dotfiles-lordwerdes"
done

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

  Дистрибутив: $DISTRO
  GPU:         ${GPU:-не определён}
  Конфиги:     ~/.config/hypr, ~/.config/waybar, ~/.config/wofi, ~/.config/kitty
  Бэкап:       $BACKUP
  Откат:       ./uninstall.sh

  Обои по умолчанию отключены — Hyprland рисует тёмный фон.
  Как включить обои, написано в config/hypr/hyprpaper.conf.

  Основное:
    Super + Enter   терминал
    Super + D       лаунчер / закрыть лаунчер
    Super + H       шпаргалка по биндам
    Print           скриншот области в буфер
    Super + Print   весь экран в ~/Pictures

  YouTube: https://www.youtube.com/@LordWerdes
  Telegram: https://t.me/lordwerdes1337
EOF
