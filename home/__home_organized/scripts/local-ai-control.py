#!/usr/bin/env python3
"""Local AI control surface for the existing Ollama/OpenClaw/Obsidian stack."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path


HOME = Path.home()
OBSIDIAN = HOME / "Desktop/Obsidian"
DASHBOARD = OBSIDIAN / "ИИ/Local AI Control Center.md"
RUNTIME = HOME / "__home_organized/runtime/local-ai-control"
STATE = RUNTIME / "state.json"


FEATURES = [
    {
        "name": "Unified local chat and model UX",
        "best_tool": "Open WebUI",
        "status": "candidate",
        "why": "Chat UI, Ollama connection, model selection, files, tools, functions, admin controls.",
    },
    {
        "name": "Document RAG with hybrid search and rerank",
        "best_tool": "Open WebUI / AnythingLLM",
        "status": "candidate",
        "why": "Useful for Obsidian/project docs; external docs show BM25 + reranking in Open WebUI.",
    },
    {
        "name": "Workspace knowledge bases",
        "best_tool": "AnythingLLM",
        "status": "candidate",
        "why": "Good fit for separate workspaces: System, projects, English, codebases.",
    },
    {
        "name": "Tool/function calling",
        "best_tool": "Open WebUI tools/functions + MCP",
        "status": "candidate",
        "why": "Adds controlled web/search/code/local actions without making every model full-trust.",
    },
    {
        "name": "Always-on assistant routing",
        "best_tool": "OpenClaw",
        "status": "enabled",
        "why": "Already present: gateway, Telegram, project agents, Ollama model sync.",
    },
    {
        "name": "Local-only terminal agent",
        "best_tool": "OpenHarness",
        "status": "enabled",
        "why": "Already present as a separate Ollama-backed CLI harness.",
    },
    {
        "name": "Hardware and model telemetry in notes",
        "best_tool": "ollama_hw_obsidian_logger.py",
        "status": "enabled",
        "why": "Already writes model launch/resource usage into Obsidian.",
    },
]

EXTERNAL_SOURCES = [
    {
        "name": "Open WebUI features",
        "url": "https://docs.openwebui.com/features",
        "note": "chat UI, tools/functions, web search, code interpreter, extensibility",
    },
    {
        "name": "Open WebUI RAG",
        "url": "https://docs.openwebui.com/features/chat-conversations/rag/",
        "note": "hybrid search, BM25, reranking, file/document context",
    },
    {
        "name": "Open WebUI tools",
        "url": "https://docs.openwebui.com/features/extensibility/plugin/tools/",
        "note": "tool/function layer and MCP-style integration surface",
    },
    {
        "name": "AnythingLLM docs",
        "url": "https://docs.useanything.com/",
        "note": "workspaces, agents, Ollama provider, MCP compatibility",
    },
    {
        "name": "Qdrant with Ollama",
        "url": "https://qdrant.tech/documentation/embeddings/ollama/",
        "note": "local vector database path for custom RAG",
    },
    {
        "name": "R2R local RAG",
        "url": "https://r2r-docs.sciphi.ai/self-hosting/local-rag",
        "note": "production-style local RAG with Ollama/LM Studio backends",
    },
]


MODEL_ROLES = {
    "heavy_coding": ["qwen3-coder-next:q8_0", "minimax-m2.7:ud-iq3_s"],
    "balanced_coding": ["mdq100/qwen3.5-coder:35b", "qwen3.6:35b-a3b", "qwen3.6:27b"],
    "fast_draft": ["gpt-oss:20b", "qwen2.5:1.5b"],
    "embedding": ["nomic-embed-text:latest"],
}


def run(cmd: list[str], timeout: int = 10) -> tuple[int, str, str]:
    env = os.environ.copy()
    env.setdefault("NO_COLOR", "1")
    try:
        proc = subprocess.run(
            cmd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            env=env,
            check=False,
        )
    except FileNotFoundError as exc:
        return 127, "", str(exc)
    except subprocess.TimeoutExpired as exc:
        return 124, exc.stdout or "", exc.stderr or "timeout"
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def parse_ollama_list(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in text.splitlines()[1:]:
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) >= 4:
            rows.append(
                {
                    "name": parts[0],
                    "id": parts[1],
                    "size": parts[2],
                    "modified": parts[3],
                }
            )
    return rows


def collect_state() -> dict:
    ollama_rc, ollama_out, ollama_err = run(["ollama", "list"])
    ps_rc, ps_out, ps_err = run(["ollama", "ps"])
    gpu_rc, gpu_out, gpu_err = run(
        [
            "nvidia-smi",
            "--query-gpu=name,driver_version,memory.used,memory.total,temperature.gpu,power.draw,pstate,utilization.gpu",
            "--format=csv,noheader,nounits",
        ]
    )
    openclaw_rc, openclaw_out, openclaw_err = run(["openclaw", "status"])
    systemd_rc, systemd_out, systemd_err = run(
        [
            "systemctl",
            "--user",
            "status",
            "ollama-hw-obsidian-log.timer",
            "openclaw-ollama-sync.timer",
            "--no-pager",
        ]
    )

    models = parse_ollama_list(ollama_out) if ollama_rc == 0 else []
    installed = {item["name"] for item in models}
    recommendations = {}
    for role, candidates in MODEL_ROLES.items():
        recommendations[role] = next((m for m in candidates if m in installed), None)

    return {
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "ollama": {"rc": ollama_rc, "models": models, "error": ollama_err},
        "ollama_ps": {"rc": ps_rc, "text": ps_out, "error": ps_err},
        "gpu": {"rc": gpu_rc, "text": gpu_out, "error": gpu_err},
        "openclaw": {"rc": openclaw_rc, "text": openclaw_out, "error": openclaw_err},
        "systemd": {"rc": systemd_rc, "text": systemd_out, "error": systemd_err},
        "recommendations": recommendations,
        "features": FEATURES,
        "external_sources": EXTERNAL_SOURCES,
    }


def md_table(rows: list[list[str]]) -> str:
    if not rows:
        return ""
    widths = [max(len(str(row[i])) for row in rows) for i in range(len(rows[0]))]
    out = []
    for idx, row in enumerate(rows):
        out.append("| " + " | ".join(str(row[i]).ljust(widths[i]) for i in range(len(row))) + " |")
        if idx == 0:
            out.append("| " + " | ".join("-" * widths[i] for i in range(len(row))) + " |")
    return "\n".join(out)


def write_dashboard(state: dict) -> Path:
    DASHBOARD.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    model_rows = [["Model", "Size", "Modified"]]
    for model in state["ollama"]["models"]:
        model_rows.append([model["name"], model["size"], model["modified"]])

    rec_rows = [["Role", "Selected model"]]
    labels = {
        "heavy_coding": "Heavy coding / architecture",
        "balanced_coding": "Daily coding balance",
        "fast_draft": "Fast draft / helper",
        "embedding": "Embeddings / RAG",
    }
    for role, label in labels.items():
        rec_rows.append([label, state["recommendations"].get(role) or "not installed"])

    feature_rows = [["Feature", "Tool", "State", "Why"]]
    for feature in state["features"]:
        feature_rows.append([feature["name"], feature["best_tool"], feature["status"], feature["why"]])

    source_rows = [["Source", "Why"]]
    for source in state["external_sources"]:
        source_rows.append([f"[{source['name']}]({source['url']})", source["note"]])

    unavailable = []
    if state["ollama"]["rc"] != 0:
        unavailable.append(f"Ollama unavailable: `{state['ollama']['error']}`")
    if state["gpu"]["rc"] != 0:
        unavailable.append(f"GPU probe unavailable: `{state['gpu']['error']}`")
    if state["openclaw"]["rc"] != 0:
        unavailable.append(f"OpenClaw unavailable: `{state['openclaw']['error']}`")
    unavailable_md = "\n".join(f"- {item}" for item in unavailable) or "- No probe errors in this run."

    content = f"""# Local AI Control Center

- Updated: `{state["generated_at"]}`
- State JSON: `{STATE}`

## Probe Notes

{unavailable_md}

## Current Runtime

```text
GPU: {state["gpu"]["text"] or state["gpu"]["error"] or "unknown"}
Ollama ps:
{state["ollama_ps"]["text"] or state["ollama_ps"]["error"] or "no active models"}
OpenClaw:
{state["openclaw"]["text"] or state["openclaw"]["error"] or "unknown"}
```

## Installed Ollama Models

{md_table(model_rows) if len(model_rows) > 1 else "_Ollama model list unavailable._"}

## Recommended Local Profiles

{md_table(rec_rows)}

## Power Feature Map

{md_table(feature_rows)}

## External Research

{md_table(source_rows)}

## Practical Next Layer

1. Keep OpenClaw as always-on routing and Telegram/project-agent surface.
2. Keep OpenHarness as local-only terminal agent.
3. Add Open WebUI only if a browser UI, RAG collections, tools/functions, or MCP tool UX is needed.
4. Add AnythingLLM only if separate document workspaces and no-code agent workflows become the priority.
5. Use `nomic-embed-text:latest` as the default local embedding model for RAG experiments.

## Commands

```bash
local-ai-control status
local-ai-control dashboard
local-ai-control json
/home/goringich/__home_organized/scripts/openclaw_ollama_sync.py
```

## Source Notes

- [[ИИ/Модели/Локальные LLM/Ollama/Index]]
- [[ИИ/Модели/Локальные LLM/Ollama/Бенч локальных моделей Ollama на моем железе]]
- [[ИИ/Модели/Локальные LLM/Ollama/Лог запуска локальных моделей]]
- [[System/System Blueprint/16 Codex Configuration Map]]
"""
    DASHBOARD.write_text(content, encoding="utf-8")
    return DASHBOARD


def print_status(state: dict) -> None:
    print(f"updated: {state['generated_at']}")
    if state["ollama"]["rc"] == 0:
        print(f"models: {len(state['ollama']['models'])}")
    else:
        print(f"models: unavailable ({state['ollama']['error']})")
    for role, model in state["recommendations"].items():
        print(f"{role}: {model or 'not installed'}")
    if state["gpu"]["rc"] == 0:
        gpu = state["gpu"]["text"] or "unknown"
    else:
        gpu = f"unavailable ({state['gpu']['error'] or 'probe failed'})"
    print(f"gpu: {gpu}")
    if state["openclaw"]["rc"] != 0:
        print(f"openclaw: unavailable ({state['openclaw']['error']})")
    if state["ollama_ps"]["text"]:
        print("\nactive models:")
        print(state["ollama_ps"]["text"])


def main() -> int:
    parser = argparse.ArgumentParser(description="Local AI control surface")
    parser.add_argument("command", nargs="?", default="status", choices=["status", "dashboard", "json"])
    args = parser.parse_args()

    state = collect_state()
    if args.command == "json":
        print(json.dumps(state, ensure_ascii=False, indent=2))
        return 0
    if args.command == "dashboard":
        path = write_dashboard(state)
        print(path)
        return 0
    print_status(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
