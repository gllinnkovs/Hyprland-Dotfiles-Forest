#!/bin/sh
# Быстрый вывод кадра для Waybar: в 99% случаев это просто cat.
# Python запускается только если демон ещё не создал состояние
# или оно устарело (например, демон упал).
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/volume.json"

if [ -s "$STATE" ]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$STATE" 2>/dev/null || echo 0)
    if [ $((now - mtime)) -lt 15 ]; then
        cat "$STATE"
        exit 0
    fi
fi

exec python3 "$HOME/.config/waybar/scripts/volume.py" --print
