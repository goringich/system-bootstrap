#!/usr/bin/env python3

import json
import math
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path


CODEX_SESSIONS = Path("/home/goringich/.codex/sessions")


def fmt_local(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")


def fmt_utc(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def pct_left(value):
    return max(0, min(100, int(round(100 - float(value)))))


def next_copilot_reset():
    now = datetime.now(timezone.utc)
    month = now.month + 1
    year = now.year
    if month == 13:
        month = 1
        year += 1
    return datetime(year, month, 1, tzinfo=timezone.utc)


def latest_codex_rate_limits():
    if not CODEX_SESSIONS.exists():
        return None

    candidates = sorted(
        (p for p in CODEX_SESSIONS.rglob("*.jsonl") if p.is_file()),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )[:24]

    latest = None
    for path in candidates:
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as handle:
                for line in handle:
                    if '"type":"token_count"' not in line or '"rate_limits"' not in line:
                        continue
                    payload = json.loads(line).get("payload", {})
                    rate_limits = payload.get("rate_limits")
                    if rate_limits:
                        latest = rate_limits
        except Exception:
            continue
        if latest:
            break

    return latest


def copilot_snapshot():
    reset = next_copilot_reset()
    return {
        "text": "n/a",
        "tooltip": (
            "Copilot premium requests\n"
            "Usage source is unavailable on this machine right now.\n"
            f"Monthly counter resets: {reset.astimezone().strftime('%Y-%m-%d %H:%M')} local\n"
            f"UTC reset: {reset.strftime('%Y-%m-%d %H:%M UTC')}\n"
            "Available local checks: none\n"
            "Current blockers: GitHub CLI is not logged in and browser session is not authenticated."
        ),
        "class": ["unknown"],
    }


def build_payload():
    codex = latest_codex_rate_limits()
    copilot = copilot_snapshot()

    if codex:
        primary = codex.get("primary") or {}
        secondary = codex.get("secondary") or {}
        p_left = pct_left(primary.get("used_percent", 100))
        s_left = pct_left(secondary.get("used_percent", 100))

        tooltip_lines = [
            "Codex usage",
            f"5h window left: {p_left}%",
            f"5h reset: {fmt_local(primary.get('resets_at', 0))} local",
            f"5h UTC: {fmt_utc(primary.get('resets_at', 0))}",
            f"7d window left: {s_left}%",
            f"7d reset: {fmt_local(secondary.get('resets_at', 0))} local",
            f"7d UTC: {fmt_utc(secondary.get('resets_at', 0))}",
        ]
        if codex.get("plan_type"):
            tooltip_lines.append(f"Plan: {codex['plan_type']}")
        if codex.get("credits"):
            credits = codex["credits"]
            tooltip_lines.append(
                "Credits: "
                f"balance={credits.get('balance', 'n/a')}, "
                f"unlimited={credits.get('unlimited', False)}"
            )

        text = f"󰚩 {p_left}/{s_left}%   {copilot['text']}"
        css_class = ["normal"]
        if s_left == 0 or p_left <= 10:
            css_class = ["warning"]
        if s_left == 0 and p_left == 0:
            css_class = ["critical"]

        tooltip = "\n".join(tooltip_lines + ["", copilot["tooltip"]])
        return {
            "text": text,
            "tooltip": tooltip,
            "class": css_class + copilot["class"],
        }

    return {
        "text": f"󰚩 n/a   {copilot['text']}",
        "tooltip": "Codex usage\nNo readable local rate-limit snapshot found.\n\n" + copilot["tooltip"],
        "class": ["unknown"] + copilot["class"],
    }


print(json.dumps(build_payload(), ensure_ascii=False))
