#!/usr/bin/env bash
# Установка Hyprland dotfiles — LordWerdes
# Arch Linux и производные Arch-based дистрибутивы
set -euo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S-%N)"
BACKUP="$TARGET/dotfiles-backup-$STAMP"
DIRS=(hypr waybar wofi kitty)
DEPS=(hyprland waybar wofi kitty grim slurp wl-clipboard python python-gobject gtk3
      ttf-hack ttf-jetbrains-mono-nerd hyprpaper pipewire wireplumber libpulse
      networkmanager pavucontrol thunar brightnessctl playerctl
      hyprcursor adwaita-cursors xdg-desktop-portal-hyprland)

YES=0
NO_DEPS=0
NO_RELOAD=0
KEEP_LOCAL=0
GPU_OVERRIDE=""

c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Установка Hyprland dotfiles

  ./install.sh [--yes] [--no-deps] [--no-reload] [--keep-local] [--gpu auto|nvidia|amd|intel|hybrid]

  -y, --yes        не задавать вопросов
      --no-deps    не проверять/не ставить пакеты
      --no-reload  не перезагружать Hyprland и Waybar
      --keep-local не перезаписывать ~/.config/hypr/local.lua
      --gpu <тип>  принудительно выбрать GPU-профиль (auto по умолчанию)
  -h, --help       эта справка

  Гибридные ноутбуки (Intel/AMD + NVIDIA) определяются автоматически:
  рабочий стол остаётся на встроенной графике, NVIDIA доступна через PRIME.
  Если в BIOS включён MUX / дискретная графика — используй --gpu nvidia.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -y|--yes) YES=1 ;;
        --no-deps) NO_DEPS=1 ;;
        --no-reload) NO_RELOAD=1 ;;
        --keep-local) KEEP_LOCAL=1 ;;
        --gpu)
            [ "$#" -ge 2 ] || die "--gpu требует значение: auto|nvidia|amd|intel|hybrid"
            GPU_OVERRIDE="$2"
            shift
            ;;
        --gpu=*) GPU_OVERRIDE="${1#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) die "Неизвестный аргумент: $1" ;;
    esac
    shift
done

case "$GPU_OVERRIDE" in
    ""|auto|nvidia|amd|intel|hybrid) ;;
    *) die "Неизвестный --gpu '$GPU_OVERRIDE'. Допустимо: auto, nvidia, amd, intel, hybrid." ;;
esac

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

# ---------------------------------------------------------------- GPU
# Печатает уникальные строки "vendor boot_vga" для всех GPU.
detect_gpus() {
    local card vendor boot
    for card in /sys/class/drm/card[0-9]*; do
        [ -r "$card/device/vendor" ] || continue
        vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
        case "$vendor" in
            0x10de) vendor=nvidia ;;
            0x1002) vendor=amd ;;
            0x8086) vendor=intel ;;
            *) continue ;;
        esac
        boot="$(cat "$card/device/boot_vga" 2>/dev/null || echo 0)"
        printf '%s %s\n' "$vendor" "$boot"
    done | sort -u
}

GPU_VENDORS=()
GPU_PRIMARY=""
while read -r vendor boot; do
    [ -n "$vendor" ] || continue
    case " ${GPU_VENDORS[*]:-} " in
        *" $vendor "*) ;;
        *) GPU_VENDORS+=("$vendor") ;;
    esac
    if [ "$boot" = "1" ] && [ -z "$GPU_PRIMARY" ]; then
        GPU_PRIMARY="$vendor"
    fi
done < <(detect_gpus)

has_vendor() {
    local v
    for v in "${GPU_VENDORS[@]:-}"; do
        [ "$v" = "$1" ] && return 0
    done
    return 1
}

# Человеческое имя адаптера (если установлен pciutils)
gpu_name() {
    local pattern
    case "$1" in
        nvidia) pattern="nvidia" ;;
        amd) pattern="amd|ati" ;;
        intel) pattern="intel" ;;
        *) return 1 ;;
    esac
    command -v lspci >/dev/null 2>&1 || return 1
    lspci 2>/dev/null | grep -iE "vga|3d|display" | grep -iE "$pattern" \
        | head -1 | sed 's/.*: //'
}

GPU_KIND="unknown"
GPU_DESC="не определён"

if [ "$GPU_PRIMARY" = "nvidia" ]; then
    # NVIDIA — основной адаптер (MUX/дискретный режим)
    GPU_KIND="nvidia"; GPU_DESC="NVIDIA"
elif has_vendor nvidia && { has_vendor intel || has_vendor amd; }; then
    if has_vendor intel; then
        GPU_KIND="hybrid-intel-nvidia"
        GPU_DESC="гибрид: Intel iGPU + NVIDIA dGPU"
    else
        GPU_KIND="hybrid-amd-nvidia"
        GPU_DESC="гибрид: AMD iGPU + NVIDIA dGPU"
    fi
elif has_vendor intel && has_vendor amd; then
    GPU_KIND="hybrid-intel-amd"
    GPU_DESC="гибрид: Intel + AMD"
elif has_vendor nvidia; then
    GPU_KIND="nvidia"; GPU_DESC="NVIDIA"
elif has_vendor amd; then
    GPU_KIND="amd"; GPU_DESC="AMD"
elif has_vendor intel; then
    GPU_KIND="intel"; GPU_DESC="Intel"
fi

# Ручное переопределение профиля
case "$GPU_OVERRIDE" in
    nvidia) GPU_KIND="nvidia"; GPU_DESC="NVIDIA (принудительно)" ;;
    amd)    GPU_KIND="amd";    GPU_DESC="AMD (принудительно)" ;;
    intel)  GPU_KIND="intel";  GPU_DESC="Intel (принудительно)" ;;
    hybrid)
        if has_vendor nvidia && has_vendor intel; then
            GPU_KIND="hybrid-intel-nvidia"; GPU_DESC="гибрид: Intel iGPU + NVIDIA dGPU"
        elif has_vendor nvidia && has_vendor amd; then
            GPU_KIND="hybrid-amd-nvidia"; GPU_DESC="гибрид: AMD iGPU + NVIDIA dGPU"
        elif has_vendor intel && has_vendor amd; then
            GPU_KIND="hybrid-intel-amd"; GPU_DESC="гибрид: Intel + AMD"
        else
            warn "Гибридная графика не обнаружена — оставляю автоопределение."
        fi
        ;;
esac

info "GPU: $GPU_DESC"
if [ "${#GPU_VENDORS[@]}" -gt 0 ]; then
    info "Найдено GPU: ${GPU_VENDORS[*]}${GPU_PRIMARY:+, основной: $GPU_PRIMARY}"
    for vendor in "${GPU_VENDORS[@]}"; do
        name="$(gpu_name "$vendor" || true)"
        [ -n "$name" ] && info "  $vendor: $name"
    done
fi

# Подсказка для гибридных ноутбуков
case "$GPU_KIND" in
    hybrid-*)
        warn "Гибридная графика: рабочий стол будет на встроенной, NVIDIA — через PRIME."
        warn "Если в BIOS включён MUX (только дискретная) — запусти: ./install.sh --gpu nvidia"
        ;;
esac

# ---------------------------------------------------------------- CURSOR
# Ищем реально установленную тему курсора. Если оставить пусто, Hyprland
# может синхронизироваться с gsettings, где прописан отсутствующий курсор —
# именно из-за этого на некоторых системах курсор исчезает.
detect_cursor_theme() {
    local theme dir
    for theme in Bibata-Mint Bibata-Modern-Ice Bibata-Modern-Classic Adwaita default; do
        for dir in "$HOME/.icons/$theme" "$HOME/.local/share/icons/$theme" \
                   "/usr/share/icons/$theme" "/usr/local/share/icons/$theme"; do
            if [ -d "$dir/cursors" ] || [ -d "$dir/hyprcursors" ]; then
                printf '%s' "$theme"
                return 0
            fi
        done
    done
    for dir in "$HOME/.icons"/* "$HOME/.local/share/icons"/* /usr/share/icons/*; do
        { [ -d "$dir/cursors" ] || [ -d "$dir/hyprcursors" ]; } || continue
        theme="$(basename "$dir")"
        theme="$(printf '%s' "$theme" | tr -cd 'A-Za-z0-9._-')"
        [ -n "$theme" ] || continue
        printf '%s' "$theme"
        return 0
    done
    return 1
}

CURSOR_THEME="$(detect_cursor_theme || true)"
if [ -n "$CURSOR_THEME" ]; then
    info "Курсор: $CURSOR_THEME"
else
    warn "Не найдена ни одна тема курсора. Поставь adwaita-cursors или свой курсор."
fi

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
            warn "Обнови Hyprland (sudo pacman -Syu hyprland), иначе конфиг не загрузится."
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
        printf '%s\n' "-- GPU: $GPU_DESC. При следующей установке файл перезапишется"
        printf '%s\n' "-- (если не запускать install.sh с --keep-local)."
        case "$GPU_KIND" in
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
            hybrid-intel-nvidia)
                printf '%s\n' '-- Гибридная графика: рабочий стол на Intel, NVIDIA — через PRIME.'
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "iHD")'
                printf '%s\n' '-- Для игр/рендера:'
                printf '%s\n' '-- __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <команда>'
                printf '%s\n' '-- Если в BIOS включён MUX (только NVIDIA): ./install.sh --gpu nvidia'
                ;;
            hybrid-amd-nvidia)
                printf '%s\n' '-- Гибридная графика: рабочий стол на AMD, NVIDIA — через PRIME.'
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "radeonsi")'
                printf '%s\n' '-- Для игр/рендера:'
                printf '%s\n' '-- __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <команда>'
                printf '%s\n' '-- Если в BIOS включён MUX (только NVIDIA): ./install.sh --gpu nvidia'
                ;;
            hybrid-intel-amd)
                printf '%s\n' '-- Гибридная графика: Intel + AMD.'
                printf '%s\n' 'hl.env("LIBVA_DRIVER_NAME", "iHD")'
                ;;
            *)
                printf '%s\n' '-- GPU не определён: стандартные настройки.'
                ;;
        esac
        if [ -n "$CURSOR_THEME" ]; then
            printf 'hl.env("XCURSOR_THEME", "%s")\n' "$CURSOR_THEME"
            printf 'hl.env("HYPRCURSOR_THEME", "%s")\n' "$CURSOR_THEME"
            # на случай, если тема не подхватилась из env — применим после старта
            printf '%s\n' 'cursor_theme = "'"$CURSOR_THEME"'"'
        else
            printf '%s\n' '-- Тема курсора не найдена: поставь adwaita-cursors или свой курсор.'
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

        # принудительно применяем курсор (лечит пропажу курсора)
        if [ -n "$CURSOR_THEME" ]; then
            hyprctl setcursor "$CURSOR_THEME" 24 >/dev/null 2>&1 || true
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

  Дистрибутив: $DISTRO
  GPU:         $GPU_DESC
  Курсор:      ${CURSOR_THEME:-не найден}
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
