#!/usr/bin/env python3

import json
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path


OBSIDIAN_LOG = Path("/home/goringich/Desktop/Obsidian/ИИ/Модели/Локальные LLM/Ollama/Лог запуска локальных моделей.md")
STATE_DIR = Path("/home/goringich/__home_organized/runtime/ollama-hw-logger")
STATE_PATH = STATE_DIR / "state.json"

TABLE_HEADER = [
    "# Лог запуска локальных моделей",
    "",
    "Автоматический агрегированный лог локальных моделей Ollama.",
    "На одну активную сессию модели пишутся две строки: `REQ` и `STAT`.",
    "",
    "| Start | End | Ses | Kind | Model | Proc | Ctx | Dur s | N | GPU avg/max % | VRAM avg/max MiB | RAM avg/max GiB | Temp max C | Power avg/max W | Notes |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
]


def default_state():
    return {
        "active": False,
        "session": 0,
        "signature": "",
        "models": "",
        "processor": "",
        "context": "",
        "started_at": None,
        "sample_count": 0,
        "sum_gpu_util": 0.0,
        "sum_vram_mib": 0.0,
        "sum_ram_used_gib": 0.0,
        "sum_power_w": 0.0,
        "max_gpu_util": 0.0,
        "max_vram_mib": 0.0,
        "max_ram_used_gib": 0.0,
        "max_temp_c": 0.0,
        "max_power_w": 0.0,
    }


def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def ensure_parent_paths():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    OBSIDIAN_LOG.parent.mkdir(parents=True, exist_ok=True)
    if not OBSIDIAN_LOG.exists():
        OBSIDIAN_LOG.write_text("\n".join(TABLE_HEADER) + "\n", encoding="utf-8")


def load_state():
    if not STATE_PATH.exists():
        return default_state()
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default_state()


def save_state(state):
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=True, indent=2), encoding="utf-8")


def parse_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def parse_ollama_ps(stdout):
    lines = [line.rstrip() for line in stdout.splitlines() if line.strip()]
    if len(lines) <= 1:
        return []

    rows = []
    for line in lines[1:]:
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) < 6:
            continue
        name, model_id, size, processor, context, until = parts[:6]
        rows.append(
            {
                "name": name,
                "id": model_id,
                "size": size,
                "processor": processor,
                "context": context,
                "until": until,
            }
        )
    return rows


def gather_hardware():
    _, free_out, _ = run_cmd(["free", "-b"])
    ram_used_gib = 0.0
    for line in free_out.splitlines():
        if line.startswith("Mem:"):
            parts = line.split()
            if len(parts) >= 3:
                ram_used_gib = int(parts[2]) / 1024**3
            break

    gpu_fields = {
        "gpu_util": 0.0,
        "gpu_mem_used": 0.0,
        "gpu_temp": 0.0,
        "gpu_power": 0.0,
    }
    rc, gpu_out, _ = run_cmd(
        [
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits",
        ]
    )
    if rc == 0 and gpu_out:
        parts = [part.strip() for part in gpu_out.splitlines()[0].split(",")]
        if len(parts) >= 4:
            gpu_fields = {
                "gpu_util": parse_float(parts[0]),
                "gpu_mem_used": parse_float(parts[1]),
                "gpu_temp": parse_float(parts[2]),
                "gpu_power": parse_float(parts[3]),
            }

    return {
        **gpu_fields,
        "ram_used_gib": ram_used_gib,
    }


def escape_md(value):
    return str(value).replace("|", "\\|")


def shorten_model_name(name):
    if "/" in name:
        return name.split("/", 1)[1]
    return name


def signature_for(rows):
    return " || ".join(
        f"{row['name']}::{row['processor']}::{row['context']}::{row['until']}" for row in rows
    )


def compact_timestamp(epoch_seconds):
    return datetime.fromtimestamp(epoch_seconds).astimezone().strftime("%m-%d %H:%M:%S")


def format_avg_max(avg_value, max_value, digits=1):
    return f"{avg_value:.{digits}f}/{max_value:.{digits}f}"


def append_row(
    start_time,
    end_time,
    session,
    kind,
    models,
    processor,
    context,
    duration_s,
    samples,
    gpu_util,
    vram_mib,
    ram_gib,
    temp_c,
    power_w,
    notes="",
):
    row = (
        f"| {escape_md(start_time)} | {escape_md(end_time)} | {session} | {kind} | "
        f"{escape_md(models)} | {escape_md(processor)} | {escape_md(context)} | "
        f"{escape_md(duration_s)} | {escape_md(samples)} | {escape_md(gpu_util)} | "
        f"{escape_md(vram_mib)} | {escape_md(ram_gib)} | {escape_md(temp_c)} | "
        f"{escape_md(power_w)} | {escape_md(notes)} |"
    )
    with OBSIDIAN_LOG.open("a", encoding="utf-8") as handle:
        handle.write(row + "\n")


def update_stats(state, hardware):
    state["sample_count"] = int(state.get("sample_count", 0)) + 1
    state["sum_gpu_util"] = float(state.get("sum_gpu_util", 0.0)) + hardware["gpu_util"]
    state["sum_vram_mib"] = float(state.get("sum_vram_mib", 0.0)) + hardware["gpu_mem_used"]
    state["sum_ram_used_gib"] = float(state.get("sum_ram_used_gib", 0.0)) + hardware["ram_used_gib"]
    state["sum_power_w"] = float(state.get("sum_power_w", 0.0)) + hardware["gpu_power"]
    state["max_gpu_util"] = max(float(state.get("max_gpu_util", 0.0)), hardware["gpu_util"])
    state["max_vram_mib"] = max(float(state.get("max_vram_mib", 0.0)), hardware["gpu_mem_used"])
    state["max_ram_used_gib"] = max(float(state.get("max_ram_used_gib", 0.0)), hardware["ram_used_gib"])
    state["max_temp_c"] = max(float(state.get("max_temp_c", 0.0)), hardware["gpu_temp"])
    state["max_power_w"] = max(float(state.get("max_power_w", 0.0)), hardware["gpu_power"])


def begin_session(state, signature, models, processor, context, hardware):
    state["session"] = int(state.get("session", 0)) + 1
    state["active"] = True
    state["signature"] = signature
    state["models"] = models
    state["processor"] = processor
    state["context"] = context
    state["started_at"] = time.time()
    state["sample_count"] = 0
    state["sum_gpu_util"] = 0.0
    state["sum_vram_mib"] = 0.0
    state["sum_ram_used_gib"] = 0.0
    state["sum_power_w"] = 0.0
    state["max_gpu_util"] = 0.0
    state["max_vram_mib"] = 0.0
    state["max_ram_used_gib"] = 0.0
    state["max_temp_c"] = 0.0
    state["max_power_w"] = 0.0
    update_stats(state, hardware)


def reset_after_finalize(state):
    state.update(default_state() | {"session": int(state.get("session", 0))})


def finalize_session(state, notes=""):
    if not state.get("active") or not state.get("started_at"):
        return

    samples = max(int(state.get("sample_count", 0)), 1)
    ended_at = time.time()
    duration_s = f"{ended_at - float(state['started_at']):.1f}"
    start_text = compact_timestamp(float(state["started_at"]))
    end_text = compact_timestamp(ended_at)

    append_row(
        start_text,
        end_text,
        state["session"],
        "REQ",
        state.get("models", ""),
        state.get("processor", ""),
        state.get("context", ""),
        duration_s,
        samples,
        "",
        "",
        "",
        "",
        "",
        notes or "completed",
    )
    append_row(
        start_text,
        end_text,
        state["session"],
        "STAT",
        state.get("models", ""),
        state.get("processor", ""),
        state.get("context", ""),
        duration_s,
        samples,
        format_avg_max(float(state["sum_gpu_util"]) / samples, float(state["max_gpu_util"])),
        format_avg_max(float(state["sum_vram_mib"]) / samples, float(state["max_vram_mib"])),
        format_avg_max(float(state["sum_ram_used_gib"]) / samples, float(state["max_ram_used_gib"]), digits=2),
        f"{float(state['max_temp_c']):.1f}",
        format_avg_max(float(state["sum_power_w"]) / samples, float(state["max_power_w"])),
        "avg/max hardware",
    )
    reset_after_finalize(state)


def main():
    ensure_parent_paths()
    state = load_state()

    rc, ps_out, _ = run_cmd(["ollama", "ps"])
    if rc != 0:
        return 0

    rows = parse_ollama_ps(ps_out)
    hardware = gather_hardware()

    if not rows:
        if state.get("active"):
            finalize_session(state, notes="model unloaded")
            save_state(state)
        return 0

    models = ", ".join(shorten_model_name(row["name"]) for row in rows)
    processor = " ; ".join(row["processor"] for row in rows)
    context = " ; ".join(row["context"] for row in rows)
    signature = signature_for(rows)

    if state.get("active") and state.get("signature") != signature:
        finalize_session(state, notes="signature changed")
        begin_session(state, signature, models, processor, context, hardware)
    elif not state.get("active"):
        begin_session(state, signature, models, processor, context, hardware)
    else:
        update_stats(state, hardware)

    state["updated_at"] = int(time.time())
    save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
