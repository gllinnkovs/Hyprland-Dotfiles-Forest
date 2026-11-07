#!/usr/bin/env python3
"""Аккуратная шпаргалка по биндам Hyprland.

Это не wofi-список: здесь нет кликабельных строк, всё разложено по
секциям, а клавиши оформлены как кнопки. Закрывается по Esc.
"""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

GLib.set_prgname("bindhelp")
GLib.set_application_name("Шпаргалка по биндам")

BINDINGS = [
    (
        "Основное",
        [
            ("Super + Enter", "Терминал (kitty)"),
            ("Super + D", "Лаунчер приложений"),
            ("Super + H", "Эта шпаргалка"),
            ("Super + E", "Файловый менеджер (Thunar)"),
            ("Super + Q", "Закрыть окно"),
            ("Super + V", "Плавающее окно"),
            ("Super + F", "Полный экран"),
            ("Super + P", "Псевдоплитка"),
            ("Super + J", "Переключить сплит"),
        ],
    ),
    (
        "Раскладка",
        [
            ("Alt + Shift", "Переключение RU / EN"),
        ],
    ),
    (
        "Окна",
        [
            ("Super + ← ↑ ↓ →", "Фокус между окнами"),
            ("Super + Shift + ← ↑ ↓ →", "Перенести окно"),
            ("Super + ЛКМ", "Перетаскивать окно"),
            ("Super + ПКМ", "Менять размер окна"),
        ],
    ),
    (
        "Рабочие столы",
        [
            ("Super + 1 … 5", "Перейти на стол"),
            ("Super + Shift + 1 … 5", "Окно на стол"),
            ("Super + Ctrl + ← / →", "Следующий / предыдущий стол"),
            ("Super + колесо", "Листать столы"),
        ],
    ),
    (
        "Scratchpad",
        [
            ("Super + S", "Показать / спрятать стол magic"),
            ("Super + Shift + S", "Закинуть окно в magic"),
        ],
    ),
    (
        "Звук",
        [
            ("Super + Alt + ↑ / ↓", "Громкость ±5%"),
            ("Super + Alt + Space", "Выключить / включить звук"),
            ("XF86 Volume", "Громкость с медиа-клавиш"),
        ],
    ),
    (
        "Система и скриншоты",
        [
            ("Super + L", "Погасить экран"),
            ("Super + Shift + R", "Перезагрузить конфиг"),
            ("Super + Shift + C", "Выход из Hyprland"),
            ("Print", "Скриншот области в буфер"),
            ("Super + Print", "Скриншот всего экрана в ~/Pictures"),
        ],
    ),
]

CSS = b"""
window {
    background-color: rgba(10, 16, 12, 0.82);
}

.root {
    padding: 20px 24px 16px 24px;
}

.title {
    color: #dcefe3;
    font-size: 18px;
    font-weight: bold;
}

.subtitle {
    color: #7fc79e;
    font-size: 11px;
}

.footer {
    color: #6f8579;
    font-size: 11px;
    padding-top: 12px;
}

label.section {
    color: #7fc79e;
    font-size: 11px;
    font-weight: bold;
    margin-top: 6px;
}

label.key {
    background-color: #142019;
    border: 1px solid #2f5a45;
    border-radius: 6px;
    padding: 2px 9px;
    color: #dcefe3;
    font-weight: bold;
}

label.desc {
    color: #b8ccbf;
    padding: 2px 0;
}

button.close {
    background: transparent;
    border: none;
    box-shadow: none;
    color: #7fc79e;
    font-size: 16px;
    padding: 0 4px;
    min-width: 0;
    min-height: 0;
}

button.close:hover {
    color: #d0916b;
}

separator {
    background-color: #1c3026;
    min-height: 1px;
}

scrollbar {
    -GtkRange-slider-width: 6;
    -GtkRange-trough-border: 0;
    background: transparent;
    background-image: none;
    border: none;
}

scrollbar trough {
    background: transparent;
    background-image: none;
    border: none;
}

scrollbar slider {
    background-color: rgba(62, 124, 91, 0.55);
    background-image: none;
    border: none;
    border-radius: 3px;
    box-shadow: none;
    min-width: 6px;
    min-height: 36px;
}

scrollbar slider:hover {
    background-color: #3e7c5b;
}
"""


def build_window():
    window = Gtk.Window(title="Шпаргалка по биндам")
    window.set_decorated(False)
    window.set_app_paintable(True)
    window.set_resizable(False)
    window.set_skip_taskbar_hint(True)
    window.set_skip_pager_hint(True)
    window.set_default_size(760, 860)
    window.set_position(Gtk.WindowPosition.CENTER_ALWAYS)

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    root.get_style_context().add_class("root")

    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

    titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
    title = Gtk.Label(label="Горячие клавиши", xalign=0)
    title.get_style_context().add_class("title")
    subtitle = Gtk.Label(label="Hyprland", xalign=0)
    subtitle.get_style_context().add_class("subtitle")
    titles.pack_start(title, False, False, 0)
    titles.pack_start(subtitle, False, False, 0)

    close = Gtk.Button(label="✕")
    close.get_style_context().add_class("close")
    close.set_relief(Gtk.ReliefStyle.NONE)
    close.set_valign(Gtk.Align.START)
    close.connect("clicked", lambda *_: window.destroy())

    header.pack_start(titles, True, True, 0)
    header.pack_end(close, False, False, 0)

    grid = Gtk.Grid()
    grid.set_row_spacing(7)
    grid.set_column_spacing(22)
    grid.set_margin_top(14)

    row = 0
    for index, (section, items) in enumerate(BINDINGS):
        section_label = Gtk.Label(label=section, xalign=0)
        section_label.get_style_context().add_class("section")
        grid.attach(section_label, 0, row, 2, 1)
        row += 1

        for key, description in items:
            key_label = Gtk.Label(label=key, xalign=0)
            key_label.get_style_context().add_class("key")
            key_label.set_halign(Gtk.Align.START)

            desc_label = Gtk.Label(label=description, xalign=0)
            desc_label.get_style_context().add_class("desc")
            desc_label.set_hexpand(True)

            grid.attach(key_label, 0, row, 1, 1)
            grid.attach(desc_label, 1, row, 1, 1)
            row += 1

        if index != len(BINDINGS) - 1:
            separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
            separator.set_margin_top(9)
            separator.set_margin_bottom(9)
            separator.set_hexpand(True)
            grid.attach(separator, 0, row, 2, 1)
            row += 1

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS)
    scroll.set_overlay_scrolling(False)
    scroll.set_vexpand(True)
    scroll.add(grid)

    footer = Gtk.Label(
        label="Esc — закрыть   ·   Super + H — открыть / закрыть",
        xalign=0,
    )
    footer.get_style_context().add_class("footer")

    root.pack_start(header, False, False, 0)
    root.pack_start(scroll, True, True, 0)
    root.pack_start(footer, False, False, 0)
    window.add(root)

    window.connect("key-press-event", on_key_press)
    window.connect("destroy", Gtk.main_quit)
    return window


def on_key_press(_window, event):
    if event.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
        return True
    return False


def main():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    window = build_window()
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
