#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import os
import shutil
import subprocess
import time


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def bar(label, value, width):
    filled = int(max(0.0, min(1.0, value)) * width)
    return f"{label:<8} [{'#' * filled}{'.' * (width - filled)}] {int(value * 100):>3}%"


def mem_ratio():
    data = run("free -b")
    for line in data.splitlines():
        if line.startswith("Mem:"):
            parts = line.split()
            total = max(1, int(parts[1]))
            used = int(parts[2])
            return used / total
    return 0.0


def cpu_ratio():
    data = run("grep 'cpu ' /proc/stat")
    parts = data.split()
    if len(parts) < 8:
        return 0.0
    vals1 = list(map(int, parts[1:8]))
    idle1 = vals1[3] + vals1[4]
    total1 = sum(vals1)
    time.sleep(0.15)
    data = run("grep 'cpu ' /proc/stat")
    parts = data.split()
    vals2 = list(map(int, parts[1:8]))
    idle2 = vals2[3] + vals2[4]
    total2 = sum(vals2)
    totald = max(1, total2 - total1)
    idled = idle2 - idle1
    return max(0.0, min(1.0, 1.0 - idled / totald))


while True:
    cols, rows = shutil.get_terminal_size((100, 30))
    width = max(20, min(34, cols - 24))
    host = run("hostname")
    uptime = run("uptime -p | sed 's/^up //'")
    kernel = run("uname -r")
    disk = run("df -h / | awk 'NR==2 {print $3\" / \"$2\" (\"$5\")\"}'")
    top = run("procs --sortd cpu 2>/dev/null | sed -n '4,9p'") or run("ps -eo comm,%cpu,%mem --sort=-%cpu | sed -n '2,7p'")
    load = run("uptime | sed 's/.*load average: //'")

    lines = [
        " SYSTEM RADAR",
        "",
        f" host    {host}",
        f" kernel  {kernel}",
        f" uptime  {uptime}",
        f" load    {load}",
        f" disk    {disk}",
        "",
        bar("cpu", cpu_ratio(), width),
        bar("mem", mem_ratio(), width),
        "",
        " hot processes",
        top,
    ]

    print("\033[H\033[2J" + "\n".join(lines), end="", flush=True)
    time.sleep(1.25)
PY
