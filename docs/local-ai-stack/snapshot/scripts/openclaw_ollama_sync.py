#!/usr/bin/env python3
"""Sync installed Ollama chat models into OpenClaw model catalogs."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


HOME = Path.home()
OPENCLAW_DIR = HOME / ".openclaw"
OPENCLAW_CONFIG = OPENCLAW_DIR / "openclaw.json"
REAL_OLLAMA = Path("/usr/local/bin/ollama")

EMBEDDING_MARKERS = (
    "embed",
    "embedding",
    "nomic-embed",
    "bge-",
    "mxbai-embed",
    "snowflake-arctic-embed",
)


def run_ollama_list() -> list[str]:
    proc = subprocess.run(
        [str(REAL_OLLAMA), "list"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    names: list[str] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("NAME "):
            continue
        names.append(line.split()[0])
    return names


def is_chat_model(model: str) -> bool:
    lowered = model.lower()
    return not any(marker in lowered for marker in EMBEDDING_MARKERS)


def context_window(model: str) -> int:
    lowered = model.lower()
    if "qwen3.6" in lowered:
        return 262_144
    if "minimax" in lowered:
        return 65_536
    if "gpt-oss" in lowered:
        return 64_000
    if "qwen" in lowered:
        return 64_000
    return 32_768


def max_tokens(model: str) -> int:
    lowered = model.lower()
    if "qwen3.6" in lowered:
        return 81_920
    if "reason" in lowered or "thinking" in lowered:
        return 65_536
    return 8_192


def reasoning(model: str) -> bool:
    lowered = model.lower()
    return any(token in lowered for token in ("reason", "thinking", "minimax", "qwen3.6"))


def model_entry(model: str, existing: dict[str, Any] | None = None) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "id": model,
        "name": model,
        "reasoning": reasoning(model),
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": context_window(model),
        "maxTokens": max_tokens(model),
    }
    if existing:
        entry.update(existing)
        entry["id"] = model
        entry["name"] = model
        entry.setdefault("cost", {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0})
        entry.setdefault("input", ["text"])
        entry["contextWindow"] = max(int(entry.get("contextWindow", 0)), context_window(model))
        entry["maxTokens"] = max(int(entry.get("maxTokens", 0)), max_tokens(model))
    return entry


def alias_for(model: str, used: set[str]) -> str:
    base = model.split("/")[-1].split(":")[0].lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-") or "ollama-model"
    alias = base
    suffix = 2
    while alias in used:
        alias = f"{base}-{suffix}"
        suffix += 1
    used.add(alias)
    return alias


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> bool:
    old = path.read_text(encoding="utf-8") if path.exists() else ""
    new = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if old == new:
        return False
    path.write_text(new, encoding="utf-8")
    return True


def sync_agent_catalog(path: Path, models: list[str]) -> bool:
    payload = load_json(path)
    providers = payload.setdefault("providers", {})
    ollama = providers.setdefault(
        "ollama",
        {
            "baseUrl": "http://127.0.0.1:11434",
            "api": "ollama",
            "apiKey": "OLLAMA_API_KEY",
            "models": [],
        },
    )
    current = {
        item.get("id"): item
        for item in ollama.get("models", [])
        if isinstance(item, dict) and item.get("id")
    }
    ollama["models"] = [model_entry(model, current.get(model)) for model in models]
    return write_json(path, payload)


def sync_openclaw_config(models: list[str]) -> bool:
    payload = load_json(OPENCLAW_CONFIG)
    defaults = payload.setdefault("agents", {}).setdefault("defaults", {})
    registry = defaults.setdefault("models", {})
    used_aliases = {
        item.get("alias")
        for item in registry.values()
        if isinstance(item, dict) and item.get("alias")
    }
    used_aliases = {str(alias) for alias in used_aliases if alias}

    changed = False
    for model in models:
        key = f"ollama/{model}"
        existing = registry.get(key)
        if not isinstance(existing, dict):
            registry[key] = {"alias": alias_for(model, used_aliases)}
            changed = True
        elif not existing.get("alias"):
            existing["alias"] = alias_for(model, used_aliases)
            changed = True

    if changed:
        return write_json(OPENCLAW_CONFIG, payload)
    return False


def main() -> int:
    restart_gateway = "--restart-gateway-on-change" in sys.argv[1:]

    if not OPENCLAW_CONFIG.is_file():
        print(f"missing OpenClaw config: {OPENCLAW_CONFIG}", file=sys.stderr)
        return 2
    if not REAL_OLLAMA.exists():
        print(f"missing Ollama binary: {REAL_OLLAMA}", file=sys.stderr)
        return 2

    models = [model for model in run_ollama_list() if is_chat_model(model)]
    changed: list[Path] = []

    if sync_openclaw_config(models):
        changed.append(OPENCLAW_CONFIG)

    for path in sorted(OPENCLAW_DIR.glob("agents/*/agent/models.json")):
        if sync_agent_catalog(path, models):
            changed.append(path)

    print(f"ollama chat models: {len(models)}")
    for model in models:
        print(f"- ollama/{model}")
    if changed:
        print("updated:")
        for path in changed:
            print(f"- {path}")
        if restart_gateway:
            subprocess.run(["openclaw", "gateway", "restart"], check=False)
    else:
        print("OpenClaw catalogs already current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
