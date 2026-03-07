#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import random
import shutil
import sys
import time

random.seed(7)
stars = []

def reset_star(width, height):
    return [random.uniform(-width / 2, width / 2), random.uniform(-height / 2, height / 2), random.uniform(0.2, 1.0)]

try:
    while True:
        cols, rows = shutil.get_terminal_size((80, 24))
        width = max(40, cols)
        height = max(12, rows - 2)
        count = max(80, width * height // 55)
        while len(stars) < count:
            stars.append(reset_star(width, height))
        if len(stars) > count:
            del stars[count:]

        buf = [[" " for _ in range(width)] for _ in range(height)]
        cx = width // 2
        cy = height // 2
        for star in stars:
            star[2] += 0.035
            sx = int(cx + star[0] / star[2])
            sy = int(cy + star[1] / star[2])
            if 0 <= sx < width and 0 <= sy < height:
                char = "." if star[2] < 0.45 else "+" if star[2] < 0.75 else "*"
                buf[sy][sx] = char
            if star[2] > 1.1:
                star[:] = reset_star(width, height)

        title = " LOCAL STARFIELD // offline fallback "
        start = max(0, (width - len(title)) // 2)
        for i, ch in enumerate(title[:width]):
            buf[0][start + i] = ch

        sys.stdout.write("\x1b[H\x1b[2J")
        for row in buf:
            sys.stdout.write("".join(row) + "\n")
        sys.stdout.flush()
        time.sleep(0.04)
except KeyboardInterrupt:
    pass
PY
