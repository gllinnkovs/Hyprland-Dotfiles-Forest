#!/usr/bin/env python3
"""Плавный индикатор громкости для Waybar.

Режимы:
  volume.py --print   — отдать Waybar текущий кадр (JSON)
  volume.py --daemon  — слушать PipeWire/PulseAudio и анимировать полоску

Анимация сделана покадрово: демон плавно «догоняет» новое значение
громкости и на каждом кадре посылает Waybar SIGRTMIN+8, поэтому полоска
движется, а не прыгает.
"""

import fcntl
import json
import os
import re
import subprocess
import sys
import threading
import time

CACHE_DIR = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
STATE_DIR = os.path.join(CACHE_DIR, "waybar")
STATE_FILE = os.path.join(STATE_DIR, "volume.json")
LOCK_FILE = os.path.join(STATE_DIR, "volume.lock")

BAR_CELLS = 10
PARTIAL = ("", "▏", "▎", "▍", "▌", "▋", "▊", "▉")

ICONS = {
    "mute": "󰖁",
    "low": "󰕿",
    "medium": "󰖀",
    "high": "󰕾",
}

# настройки внешнего вида
C_ICON = "#8fb8a1"
C_ICON_MUTED = "#d0916b"
C_FILL = "#7fc79e"
C_FILL_MUTED = "#4f6f5e"
C_EMPTY = "#2f4c3c"


def read_volume():
    """Вернуть (громкость 0..1, выключен ли звук).

    Сначала PipeWire (wpctl), затем PulseAudio (pactl) — чтобы работало
    и на системах без wireplumber.
    """
    try:
        out = subprocess.run(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout
        muted = "[MUTED]" in out
        value = float(out.split()[1])
        return max(0.0, min(1.0, value)), muted
    except Exception:
        pass

    try:
        out = subprocess.run(
            ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout
        match = re.search(r"(\d+)%", out)
        if not match:
            raise ValueError("no volume")
        muted_out = subprocess.run(
            ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout
        return max(0.0, min(1.0, int(match.group(1)) / 100)), "yes" in muted_out.lower()
    except Exception:
        return 0.0, True


def icon_for(volume, muted):
    if muted or volume <= 0.001:
        return "mute"
    if volume < 0.34:
        return "low"
    if volume < 0.67:
        return "medium"
    return "high"


def render(volume, muted):
    cells = volume * BAR_CELLS
    full = int(cells)
    frac = cells - full

    filled = "█" * full
    used = full
    if full < BAR_CELLS and frac > 0.06:
        index = min(7, max(1, int(round(frac * 8))))
        filled += PARTIAL[index]
        used += 1

    empty = "░" * max(0, BAR_CELLS - used)
    icon = ICONS[icon_for(volume, muted)]

    icon_color = C_ICON_MUTED if muted else C_ICON
    fill_color = C_FILL_MUTED if muted else C_FILL

    text = (
        f'<span foreground="{icon_color}">{icon}</span>  '
        f'<span foreground="{fill_color}">{filled}</span>'
        f'<span foreground="{C_EMPTY}">{empty}</span>'
    )

    percent = round(volume * 100)
    if muted:
        tooltip = f"Звук выключен · {percent}%"
    else:
        tooltip = f"Громкость: {percent}%"

    return {
        "text": text,
        "tooltip": tooltip,
        "class": "muted" if muted else "normal",
    }


def notify_waybar():
    subprocess.run(
        ["pkill", "-RTMIN+8", "-x", "waybar"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def write_state(volume, muted):
    os.makedirs(STATE_DIR, exist_ok=True)
    payload = json.dumps(render(volume, muted), ensure_ascii=False)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(payload)
    os.replace(tmp, STATE_FILE)
    notify_waybar()


def print_state():
    # Пока демон анимирует — берём его кадр. Если демона нет или кадр
    # устарел, считаем громкость напрямую (Waybar всё равно покажет верно).
    try:
        if time.time() - os.path.getmtime(STATE_FILE) < 15:
            with open(STATE_FILE, encoding="utf-8") as handle:
                payload = handle.read().strip()
            if payload:
                sys.stdout.write(payload)
                return
    except OSError:
        pass

    volume, muted = read_volume()
    sys.stdout.write(json.dumps(render(volume, muted), ensure_ascii=False))


def daemon():
    os.makedirs(STATE_DIR, exist_ok=True)
    lock_handle = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return  # демон уже запущен

    volume, muted = read_volume()
    target = {"volume": volume, "muted": muted}
    target_lock = threading.Lock()

    def refresh_target(*_args):
        new_volume, new_muted = read_volume()
        with target_lock:
            target["volume"] = new_volume
            target["muted"] = new_muted

    def watch():
        while True:
            try:
                proc = subprocess.Popen(
                    ["pactl", "subscribe"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    bufsize=1,
                )
                for line in proc.stdout:
                    if "sink" in line:
                        refresh_target()
                proc.wait(timeout=0.1)
            except Exception:
                pass
            # если pactl отвалился — просто опрашиваем
            refresh_target()
            time.sleep(1.0)

    threading.Thread(target=watch, daemon=True).start()

    display = volume
    last_muted = None
    write_state(display, muted)
    last_muted = muted

    while True:
        with target_lock:
            goal = target["volume"]
            goal_muted = target["muted"]

        if abs(display - goal) < 0.002:
            display = goal
            if goal_muted != last_muted:
                write_state(display, goal_muted)
                last_muted = goal_muted
            time.sleep(0.04)
            continue

        # экспоненциальное сглаживание ≈ 250 мс до нового значения
        display += (goal - display) * 0.28
        if abs(goal - display) < 0.003:
            display = goal

        write_state(display, goal_muted)
        last_muted = goal_muted
        time.sleep(1 / 30)


def main():
    if "--print" in sys.argv:
        print_state()
    else:
        daemon()


if __name__ == "__main__":
    main()
