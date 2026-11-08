-- Локальные настройки под конкретное железо.
-- install.sh перезаписывает этот файл при установке (если не указан --keep-local).
-- hyprland.lua подхватывает его через pcall(dofile, ...), так что ошибки здесь
-- не ломают весь конфиг.

-- NVIDIA:
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.config({ cursor = { no_hardware_cursors = true } })

-- AMD:
-- hl.env("LIBVA_DRIVER_NAME", "radeonsi")

-- Intel:
-- hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Курсор Bibata (если установлен):
-- hl.env("XCURSOR_THEME", "Bibata-Mint")
