#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import math
import shutil
import sys
import time

bars = " .:-=+*#%@"
t0 = time.time()

try:
    while True:
        cols, rows = shutil.get_terminal_size((80, 24))
        width = max(32, cols - 2)
        height = max(8, rows - 6)
        now = time.time() - t0
        frame = []
        for y in range(height):
            line = []
            for x in range(width):
                value = (
                    math.sin(x * 0.18 + now * 3.2)
                    + math.cos(y * 0.55 - now * 2.4)
                    + math.sin((x + y) * 0.12 + now * 1.4)
                ) / 3.0
                idx = max(0, min(len(bars) - 1, int((value + 1.0) * 0.5 * (len(bars) - 1))))
                line.append(bars[idx])
            frame.append("".join(line))

        sys.stdout.write("\x1b[H\x1b[2J")
        sys.stdout.write(" SIGNAL PULSE\n")
        sys.stdout.write(" synthetic terminal field\n\n")
        sys.stdout.write("\n".join(frame))
        sys.stdout.flush()
        time.sleep(0.05)
except KeyboardInterrupt:
    pass
PY
