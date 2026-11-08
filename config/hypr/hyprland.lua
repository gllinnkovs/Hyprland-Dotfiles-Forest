-- Hyprland config (Lua) — LordWerdes
-- Тёмно-зелёная тема, us/ru на Alt+Shift, авто-монитор, без обоев по умолчанию.

local terminal    = "kitty"
local mainMod     = "SUPER"
local home        = os.getenv("HOME") or ""

------------------
---- MONITORS ----
------------------

-- Универсально для любого монитора: максимальное разрешение и герцовка.
-- Нужен конкретный режим — замени "highrr" на "2560x1440@165".
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = "auto",
})

-------------------
---- AUTOSTART ----
-------------------

-- Без дублей: повторный reload не плодит процессы.
hl.on("hyprland.start", function()
    hl.exec_cmd("pgrep -x waybar >/dev/null || waybar")
    hl.exec_cmd("pgrep -f '[v]olume.py' >/dev/null || " .. home .. "/.config/waybar/scripts/volume.py --daemon")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Wayland для браузеров и Electron. Безопасно для AMD, Intel и NVIDIA.
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Настройки под конкретное железо (AMD / Intel / NVIDIA, курсор).
-- Файл генерирует install.sh, но его можно править руками.
if type(dofile) == "function" then
    pcall(dofile, home .. "/.config/hypr/local.lua")
end

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 12,
        border_size = 2,

        col = {
            active_border   = { colors = { "rgb(3E7C5B)", "rgb(1E3B2F)" }, angle = 45 },
            inactive_border = "rgb(1A2420)",
        },

        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = true,
    },

    misc = {
        -- VRR только в полноэкранных приложениях/играх, рабочий стол без мерцания
        vrr = 2,
        render_unfocused_fps = 60,

        focus_on_activate = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,

        -- без обоев: фон рисует сам Hyprland
        background_color         = 0xff0a100c,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },

    decoration = {
        rounding = 10,

        active_opacity   = 0.86,
        inactive_opacity = 0.74,

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = 0xcc0B140F,
        },

        blur = {
            enabled   = true,
            size      = 11,
            passes    = 4,
            vibrancy  = 0.22,
            noise     = 0.03,
            contrast  = 1.0,
            brightness = 1.0,
            new_optimizations = true,
            ignore_opacity = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    binds = {
        workspace_back_and_forth = false,
    },
})

hl.curve("smooth", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })
-- мягкий ease-out: быстро стартует, аккуратно доезжает
hl.curve("silk", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5, bezier = "silk", style = "popin 90%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 7, bezier = "silk", style = "popin 94%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7, bezier = "silk", style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "silk" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5, bezier = "default" })
-- горизонтальный слайд между столами (а не вертикальный)
hl.animation({ leaf = "workspaces",    enabled = true, speed = 6, bezier = "silk", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 6, bezier = "silk", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 6, bezier = "silk", style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 5, bezier = "default" })
-- wofi прилетает из центра (масштабом) с фейдом
hl.animation({ leaf = "layersIn",  enabled = true, speed = 4,   bezier = "silk", style = "popin 80%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "silk", style = "popin 80%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4, bezier = "silk" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5, bezier = "silk" })

--------------------------
---- РАБОЧИЕ СТОЛЫ ----
--------------------------

-- 5 постоянных столов (всегда видны в панели)
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_options = "grp:alt_shift_toggle", -- смена раскладки Alt+Shift / Shift+Alt в любом порядке

        follow_mouse = 1,

        sensitivity   = 0,
        accel_profile = "flat", -- мышь без ускорения

        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },
})

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + Return",  hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D",       hl.dsp.exec_cmd(home .. "/.config/hypr/wofi.sh"))
hl.bind(mainMod .. " + H",       hl.dsp.exec_cmd(home .. "/.config/hypr/wofi.sh help"))
hl.bind(mainMod .. " + Q",       hl.dsp.window.close())
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + V",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",       hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind(mainMod .. " + P",       hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",       hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exit())

-- фокус стрелками
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- перенос окон
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

-- воркспейсы (5 столов)
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- скролл по воркспейсам
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- перетаскивание / ресайз окном мышью
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- громкость (клавиши медиа)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

-- яркость (ноутбуки и мониторы с подсветкой)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true })

-- медиаплеер
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- громкость с клавиатуры: Super+Alt+Вверх/Вниз/Пробел
hl.bind(mainMod .. " + ALT + up",    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind(mainMod .. " + ALT + space", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- скриншоты (Print — область в буфер, Super+Print — весь экран в ~/Pictures)
hl.bind("Print",               hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]), { locked = true })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd([[mkdir -p ~/Pictures && grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png]]), { locked = true })

--------------------------
---- ПОЛЕЗНЫЕ ФУНКЦИИ ----
--------------------------

-- scratchpad: спрятать/показать окно
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- переключение воркспейсов стрелками
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

-- выключить экран
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprctl dispatch dpms off"))

-- перезагрузка конфига
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- игнорировать maximize-запросы приложений
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- фикс драга в XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class = "^$", title = "^$", xwayland = true,
        float = true, fullscreen = false, pin = false,
    },
    no_focus = true,
})

-- плавающие диалоги
hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(pavucontrol|nm-connection-editor)$" },
    float = true,
})

-- шпаргалка (GTK-окно, без кликабельных строк)
hl.window_rule({
    name  = "bindhelp-float",
    match = { class = "^(bindhelp)$" },
    float = true,
    center = true,
    border_size = 0,
    rounding = 16,
})

-- wofi работает как layer-shell поверх окон: так у него работает
-- прозрачность и размытие фона (в режиме обычного окна GTK не отдаёт alpha)
hl.layer_rule({
    name = "wofi-blur",
    match = { namespace = "wofi" },
    blur = true,
    ignore_alpha = 0.1,
})

-- thunar: прозрачность как у kitty (88% + блюр)
hl.window_rule({
    name  = "thunar-opacity",
    match = { class = "thunar" },
    opacity = 0.88,
})
