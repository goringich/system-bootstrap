#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# This is for custom version of waybar idle_inhibitor which activates / deactivates hypridle instead

PROCESS="hypridle"

if [[ "$1" == "status" ]]; then
    if pgrep -x "$PROCESS" >/dev/null; then
        echo '{"text": " ", "class": "inactive", "tooltip": "Idle actions enabled\nLeft Click: Keep the PC awake\nRight Click: Lock screen"}'
    else
        echo '{"text": " ", "class": "active", "tooltip": "Stay awake enabled\nIdle-based lock/suspend is paused\nLeft Click: Restore idle actions\nRight Click: Lock screen"}'
    fi
elif [[ "$1" == "toggle" ]]; then
    if pgrep -x "$PROCESS" >/dev/null; then
        pkill -x "$PROCESS"
    else
        "$PROCESS" >/dev/null 2>&1 &
        disown
    fi
else
    echo "Usage: $0 {status|toggle}"
    exit 1
fi
