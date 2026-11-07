#!/bin/bash
# Лаунчер и шпаргалка.
#   wofi.sh        — открыть/закрыть лаунчер приложений
#   wofi.sh help   — открыть/закрыть шпаргалку (GTK)

MODE="${1:-run}"
HOME_DIR="${HOME:-/home/archlinux}"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/bindhelp.pid"

bindhelp_running() {
    [ -f "$PIDFILE" ] || return 1
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null) || return 1
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    # защита от переиспользования PID: это должен быть именно наш скрипт
    [ -r "/proc/$pid/cmdline" ] || return 1
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "bindhelp.py" || return 1
    return 0
}

stop_bindhelp() {
    if bindhelp_running; then
        kill "$(cat "$PIDFILE")" 2>/dev/null
    fi
    rm -f "$PIDFILE"
}

if [ "$MODE" = "help" ]; then
    if bindhelp_running; then
        stop_bindhelp
    else
        pkill -x wofi >/dev/null 2>&1
        echo $$ >"$PIDFILE"
        exec python3 "$HOME_DIR/.config/hypr/bindhelp.py"
    fi
    exit 0
fi

if pgrep -x wofi >/dev/null 2>&1; then
    pkill -x wofi
    exit 0
fi

stop_bindhelp
exec wofi --conf "$HOME_DIR/.config/wofi/config" --style "$HOME_DIR/.config/wofi/style.css"
