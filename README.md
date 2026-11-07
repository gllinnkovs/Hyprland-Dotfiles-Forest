# Hyprland Dotfiles — By LordWerdes

Тёмно-зелёное окружение для **Arch Linux**: Hyprland с Lua-конфигом, Waybar с живой полоской громкости, Wofi с прозрачностью и размытием, аккуратная GTK-шпаргалка по биндам.

![Desktop](assets/desktop.png)

## Что внутри

- **Hyprland 0.57 (Lua)** — плавные анимации окон и рабочих столов, blur, округлые углы, VRR в полноэкранных приложениях, NVIDIA-переменные.
- **Waybar** — компактный бар: анимированная полоска громкости с иконкой по уровню, подсветка активного стола, часы с русской датой, Ethernet/Wi-Fi, трей.
- **Wofi** — лаунчер на layer-shell: прозрачный фон, blur, аккуратная сетка. `Super + D` открывает и закрывает его.
- **Bindhelp** — шпаргалка по горячим клавишам на GTK3: секции, клавиши-кнопки, прокрутка, закрытие по `Esc`. `Super + H`.
- **Скриншоты** — `Print` (область в буфер) и `Super + Print` (весь экран в `~/Pictures`).
- **install.sh / uninstall.sh** — установка с бэкапом и восстановлением.

## Скриншоты

**Waybar**

![Waybar](assets/bar.png)

**Wofi**

![Wofi](assets/wofi.png)

**Шпаргалка по биндам**

![Bindhelp](assets/bindhelp.png)

## Требования

Arch Linux (или производный дистрибутив) и пакеты:

```bash
hyprland waybar wofi grim slurp wl-clipboard python-gobject gtk3 \
ttf-jetbrains-mono-nerd hyprpaper pipewire wireplumber networkmanager \
pavucontrol thunar
```

Важно: конфиг написан на **Lua** и требует **Hyprland 0.57+**. На более старых версиях `hyprland.lua` не загрузится.

`install.sh` сам проверит зависимости и предложит доустановить недостающие через `pacman`.

## Установка

```bash
cd ~/Desktop/hyprland-dotfiles
chmod +x install.sh uninstall.sh
./install.sh
```

Скрипт:

1. проверит зависимости;
2. сделает бэкап текущих `~/.config/hypr`, `~/.config/waybar`, `~/.config/wofi` в `~/.config/dotfiles-backup-ДАТА`;
3. скопирует конфиги;
4. выставит права на скрипты;
5. перезагрузит Hyprland и перезапустит Waybar и демон громкости.

Флаги:

| Флаг | Что делает |
|---|---|
| `-y`, `--yes` | не задавать вопросов |
| `--no-deps` | не проверять и не ставить пакеты |
| `--no-reload` | не перезагружать Hyprland/Waybar |
| `-h`, `--help` | справка |

## Удаление

```bash
cd ~/Desktop/hyprland-dotfiles
./uninstall.sh
```

Скрипт остановит Waybar, демон громкости и шпаргалку, затем восстановит последний бэкап из `~/.config/dotfiles-backup-*`. Если бэкапа нет — предложит удалить установленные конфиги.

Флаги: `-y`, `--yes`, `--no-reload`, `-h`, `--help`.

## Горячие клавиши

`Mod = Super (Win)`

### Основное
| Бинд | Действие |
|---|---|
| `Super+Enter` | Терминал (kitty) |
| `Super+D` | Лаунчер приложений (wofi, toggle) |
| `Super+H` | Шпаргалка по биндам (toggle) |
| `Super+E` | Файловый менеджер (Thunar) |
| `Super+Q` | Закрыть окно |
| `Super+V` | Плавающее окно |
| `Super+F` | Полный экран |
| `Super+P` | Псевдоплитка |
| `Super+J` | Переключить сплит |

### Окна и столы
| Бинд | Действие |
|---|---|
| `Super+стрелки` | Фокус между окнами |
| `Super+Shift+стрелки` | Перенести окно |
| `Super+ЛКМ` / `Super+ПКМ` | Перетаскивание / ресайз |
| `Super+1..5` | Перейти на стол |
| `Super+Shift+1..5` | Окно на стол |
| `Super+Ctrl+стрелки` | Соседний стол |
| `Super+колесо` | Листать столы |

### Scratchpad
| Бинд | Действие |
|---|---|
| `Super+S` | Показать/спрятать стол «magic» |
| `Super+Shift+S` | Закинуть окно туда |

### Звук и система
| Бинд | Действие |
|---|---|
| `Super+Alt+↑/↓` | Громкость |
| `Super+Alt+Space` | Мьют |
| `Super+L` | Погасить экран |
| `Super+Shift+R` | Перезагрузить конфиг |
| `Super+Shift+C` | Выход из Hyprland |
| `Print` | Скриншот области в буфер |
| `Super+Print` | Скриншот экрана в `~/Pictures` |

## Структура

```
hyprland-dotfiles/
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua       # основной конфиг
│   │   ├── wofi.sh            # лаунчер + шпаргалка
│   │   ├── bindhelp.py        # GTK-шпаргалка
│   │   ├── hyprpaper.conf
│   │   ├── wall.jpg
│   │   └── BINDINGS.md
│   ├── waybar/
│   │   ├── config.jsonc
│   │   ├── style.css
│   │   └── scripts/
│   │       ├── volume.py      # демон плавной громкости
│   │       └── volume-print.sh
│   └── wofi/
│       ├── config
│       └── style.css
├── assets/                    # скриншоты
├── install.sh                 # установка с бэкапом
├── uninstall.sh               # откат к бэкапу
├── LICENSE
└── README.md
```

## Настройка под себя

- Монитор и разрешение — в `config/hypr/hyprland.lua` (`hl.monitor`).
- Анимации и blur — там же, секция `decoration` и `hl.animation`.
- Цвета Waybar и Wofi — в соответствующих `style.css`.
- Громкость: демон `volume.py`, состояние в `~/.cache/waybar/volume.json`.
- Список биндов — `config/hypr/bindings.txt` и `BINDINGS.md`.

## Если что-то не так

- **Конфиг не загрузился** — выполни `hyprctl configerrors`, затем `./uninstall.sh` для отката.
- **Waybar не появился** — запусти `waybar` вручную из терминала и посмотри вывод.
- **Нет звука/полоски громкости** — проверь `wpctl status`; нужны `pipewire` и `wireplumber`.
- **Wofi без прозрачности и blur** — убедись, что Hyprland 0.57+ и в конфиге есть `hl.layer_rule` для namespace `wofi`.
- **Другой монитор** — поправь `hl.monitor` в `config/hypr/hyprland.lua` под своё разрешение и частоту.

## Соцсети

- YouTube: [@LordWerdes](https://www.youtube.com/@LordWerdes)
- Telegram: [lordwerdes1337](https://t.me/lordwerdes1337)
- Discord: `lordwerdes`, `lordwerdes1337`

## Лицензия

MIT — делай что хочешь, только не продавай как своё.
