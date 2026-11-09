-- Локальные настройки под конкретное железо.
-- install.sh перезаписывает этот файл при установке (если не указан --keep-local).
-- hyprland.lua подхватывает его через pcall(dofile, ...), так что ошибки здесь
-- не ломают весь конфиг.

-- ── NVIDIA (дискретная / MUX) ─────────────────────────────────────────────
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.config({ cursor = { no_hardware_cursors = true } })

-- ── AMD ───────────────────────────────────────────────────────────────────
-- hl.env("LIBVA_DRIVER_NAME", "radeonsi")

-- ── Intel ─────────────────────────────────────────────────────────────────
-- hl.env("LIBVA_DRIVER_NAME", "iHD")

-- ── Гибрид (Intel/AMD + NVIDIA) ───────────────────────────────────────────
-- Рабочий стол остаётся на встроенной графике, NVIDIA — через PRIME:
--   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <команда>
-- hl.env("LIBVA_DRIVER_NAME", "iHD")        -- или "radeonsi"
-- Если в BIOS включён MUX (только NVIDIA): ./install.sh --gpu nvidia

-- ── Курсор ────────────────────────────────────────────────────────────────
-- install.sh сам находит установленную тему и прописывает её сюда.
-- hl.env("XCURSOR_THEME", "Bibata-Mint")
-- hl.env("HYPRCURSOR_THEME", "Bibata-Mint")
-- cursor_theme = "Bibata-Mint"
