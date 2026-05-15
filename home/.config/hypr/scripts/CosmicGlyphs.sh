#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import random
import shutil
import sys
import time

glyphs = ".*+x#@"
streams = []
random.seed(42)

while True:
    cols, rows = shutil.get_terminal_size((80, 24))
    width = max(30, cols)
    height = max(10, rows - 1)
    while len(streams) < width:
        streams.append(random.randint(-height, 0))
    if len(streams) > width:
        streams = streams[:width]

    canvas = [[" " for _ in range(width)] for _ in range(height)]
    for x in range(width):
        streams[x] += random.randint(0, 2)
        if streams[x] > height + random.randint(2, 12):
            streams[x] = random.randint(-height, 0)
        head = streams[x]
        for trail in range(8):
            y = head - trail
            if 0 <= y < height:
                canvas[y][x] = glyphs[min(len(glyphs) - 1, trail // 2)]

    title = " COSMIC GLYPHS "
    start = max(0, (width - len(title)) // 2)
    for i, ch in enumerate(title[:width]):
        canvas[0][start + i] = ch

    sys.stdout.write("\x1b[H\x1b[2J")
    for row in canvas:
        sys.stdout.write("".join(row) + "\n")
    sys.stdout.flush()
    time.sleep(0.07)
PY
