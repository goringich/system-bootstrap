#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import random
import shutil
import sys
import time

ESC = "\x1b["
GREEN = ESC + "38;5;46m"
DIM = ESC + "38;5;34m"
RESET = ESC + "0m"
HIDE = ESC + "?25l"
SHOW = ESC + "?25h"

glyphs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ#$%&*+=-<>/\\|"
cols = []
random.seed(9)

try:
    sys.stdout.write(HIDE)
    while True:
        width, height = shutil.get_terminal_size((80, 24))
        height = max(8, height)
        while len(cols) < width:
            cols.append({
                "y": random.randint(-height, 0),
                "speed": random.randint(1, 3),
                "trail": random.randint(max(6, height // 4), max(10, height // 2)),
            })
        cols = cols[:width]

        canvas = [[" " for _ in range(width)] for _ in range(height)]
        colors = [[None for _ in range(width)] for _ in range(height)]

        for x, col in enumerate(cols):
            col["y"] += col["speed"]
            if col["y"] - col["trail"] > height:
                col["y"] = random.randint(-height, 0)
                col["speed"] = random.randint(1, 3)
                col["trail"] = random.randint(max(6, height // 4), max(10, height // 2))

            for i in range(col["trail"]):
                y = col["y"] - i
                if 0 <= y < height:
                    canvas[y][x] = random.choice(glyphs)
                    colors[y][x] = GREEN if i < 2 else DIM

        out = [ESC + "H" + ESC + "2J"]
        for y in range(height):
            line = []
            for x in range(width):
                color = colors[y][x]
                if color:
                    line.append(color + canvas[y][x])
                else:
                    line.append(" ")
            out.append("".join(line) + RESET)
        sys.stdout.write("\n".join(out))
        sys.stdout.flush()
        time.sleep(0.06)
except KeyboardInterrupt:
    pass
finally:
    sys.stdout.write(RESET + SHOW)
    sys.stdout.flush()
PY
