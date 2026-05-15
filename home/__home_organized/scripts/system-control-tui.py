#!/usr/bin/env python3
import curses
import os
import subprocess
import sys
import textwrap
from pathlib import Path


HOME = Path.home()
LOG_PATH = HOME / "__home_organized" / "logs" / "system-control-latest.md"
CONTROL_CMD = HOME / ".local" / "bin" / "system-control"


def refresh_report():
    result = subprocess.run(
        [str(CONTROL_CMD), "--compact"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "system-control refresh failed")
    if not LOG_PATH.exists():
        raise RuntimeError(f"missing report: {LOG_PATH}")
    return LOG_PATH.read_text(encoding="utf-8", errors="replace")


def parse_report(md: str):
    meta = {}
    sections = {}
    current = None

    for raw in md.splitlines():
        line = raw.rstrip()
        if line.startswith("- ") and current is None:
            if ": `" in line:
                key, value = line[2:].split(": ", 1)
                meta[key.strip()] = value.strip().strip("`")
            continue
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
            continue
        if current is not None:
            sections[current].append(line)

    order = [
        "Control Score",
        "Now",
        "Summary",
        "Local-Only Repos",
        "Promote Next",
        "Review Later",
        "Likely Noise",
        "Secret Risk Files",
        "Declared But Not Yet Captured",
    ]
    items = []
    for name in order:
        if name in sections:
            items.append((name, [ln for ln in sections[name] if ln.strip()]))
    for name, lines in sections.items():
        if name not in order:
            items.append((name, [ln for ln in lines if ln.strip()]))

    control_lines = sections.get("Control Score", [])
    for line in control_lines:
      if line.startswith("- score:"):
          meta["score"] = line.split(":", 1)[1].strip().strip("`")
      elif line.startswith("- lane:"):
          meta["lane"] = line.split(":", 1)[1].strip().strip("`")
      elif line.startswith("- runtime report:"):
          meta["runtime_report"] = line.split(":", 1)[1].strip().strip("`")
    return meta, items


def wrap_lines(lines, width):
    out = []
    width = max(12, width)
    for line in lines:
        if not line.strip():
            out.append("")
            continue
        indent = ""
        content = line
        if line.startswith("- "):
            indent = "  "
        wrapped = textwrap.wrap(
            content,
            width=width,
            subsequent_indent=indent,
            replace_whitespace=False,
            drop_whitespace=False,
        )
        out.extend(wrapped or [""])
    return out


def draw(stdscr, title, meta, sections, section_index, scroll, status):
    def safe_add(y, x, text, width_limit, attr=0):
        clean = text.replace("\n", " ")
        limit = max(1, width_limit - 1)
        try:
            stdscr.addnstr(y, x, clean.ljust(width_limit), limit, attr)
        except curses.error:
            pass

    stdscr.erase()
    height, width = stdscr.getmaxyx()
    if height < 12 or width < 60:
        stdscr.addstr(0, 0, "Window too small for system-control TUI")
        stdscr.refresh()
        return

    left_w = max(24, min(34, width // 3))
    right_x = left_w + 2
    right_w = width - right_x - 1
    content_h = height - 4

    header = f" System Control TUI  score={meta.get('score', '?')}  lane={meta.get('lane', '?')} "
    safe_add(0, 0, header, width, curses.A_REVERSE)

    safe_add(1, 0, " Sections ", left_w, curses.A_BOLD)
    safe_add(1, right_x, f" {title} ", right_w, curses.A_BOLD)

    for idx, (name, lines) in enumerate(sections[:content_h]):
        marker = ">" if idx == section_index else " "
        summary = ""
        if name == "Now":
            summary = f" ({len([ln for ln in lines if ln.startswith('- ')])})"
        elif name in ("Promote Next", "Review Later", "Likely Noise", "Secret Risk Files", "Local-Only Repos"):
            summary = f" ({len([ln for ln in lines if ln.startswith('- ')])})"
        label = f"{marker} {name}{summary}"
        attr = curses.A_REVERSE if idx == section_index else curses.A_NORMAL
        safe_add(2 + idx, 0, label, left_w, attr)

    selected_name, selected_lines = sections[section_index]
    wrapped = wrap_lines(selected_lines, right_w - 1)
    max_scroll = max(0, len(wrapped) - content_h)
    scroll = min(scroll, max_scroll)
    visible = wrapped[scroll : scroll + content_h]
    for idx, line in enumerate(visible):
        safe_add(2 + idx, right_x, line, right_w)

    footer = " j/k or arrows: section  PgUp/PgDn: scroll  r: refresh  1-6: focus  q: quit "
    safe_add(height - 2, 0, footer, width, curses.A_REVERSE)
    safe_add(height - 1, 0, status, width)
    stdscr.refresh()
    return scroll


def main(stdscr):
    curses.curs_set(0)
    stdscr.keypad(True)
    curses.use_default_colors()

    status = "Refreshing..."
    section_index = 0
    scroll = 0
    focus_map = {
        ord("1"): None,
        ord("2"): "promote",
        ord("3"): "review",
        ord("4"): "noise",
        ord("5"): "secrets",
        ord("6"): "repos",
    }

    def load():
        text = refresh_report()
        return parse_report(text)

    meta, sections = load()
    status = f"Loaded {meta.get('Generated', meta.get('Generated', 'report'))} from {LOG_PATH}"

    while True:
        title = sections[section_index][0]
        scroll = draw(stdscr, title, meta, sections, section_index, scroll, status) or 0
        ch = stdscr.getch()

        if ch in (ord("q"), 27):
            break
        if ch in (curses.KEY_DOWN, ord("j")):
            section_index = min(len(sections) - 1, section_index + 1)
            scroll = 0
        elif ch in (curses.KEY_UP, ord("k")):
            section_index = max(0, section_index - 1)
            scroll = 0
        elif ch == curses.KEY_NPAGE:
            scroll += max(1, (stdscr.getmaxyx()[0] - 4) // 2)
        elif ch == curses.KEY_PPAGE:
            scroll = max(0, scroll - max(1, (stdscr.getmaxyx()[0] - 4) // 2))
        elif ch == ord("g"):
            section_index = 0
            scroll = 0
        elif ch == ord("G"):
            section_index = len(sections) - 1
            scroll = 0
        elif ch == ord("r"):
            try:
                meta, sections = load()
                section_index = min(section_index, len(sections) - 1)
                scroll = 0
                status = f"Refreshed from {LOG_PATH}"
            except Exception as exc:
                status = f"Refresh failed: {exc}"
        elif ch in focus_map:
            focus = focus_map[ch]
            try:
                args = [str(CONTROL_CMD), "--compact"]
                if focus:
                    args.extend(["--focus", focus])
                result = subprocess.run(args, capture_output=True, text=True, check=False)
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "focus refresh failed")
                text = LOG_PATH.read_text(encoding="utf-8", errors="replace")
                meta, sections = parse_report(text)
                section_index = 0
                scroll = 0
                status = f"Focus: {focus or 'all'}"
            except Exception as exc:
                status = f"Focus switch failed: {exc}"


if __name__ == "__main__":
    if not CONTROL_CMD.exists():
        print(f"missing command: {CONTROL_CMD}", file=sys.stderr)
        sys.exit(1)
    curses.wrapper(main)
