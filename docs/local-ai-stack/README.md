# Local AI Stack Snapshot

This directory is a portable, sanitized snapshot of the local AI/LLM setup on
`cachyos` as of 2026-04-24.

It intentionally tracks configuration, scripts, service units, model catalogs,
and architecture notes. It intentionally does not track model weights, caches,
conversation logs, runtime state, or secrets.

## What Is Included

- `snapshot/ollama-models.txt` - installed Ollama model inventory.
- `snapshot/openclaw/openclaw-models.txt` - OpenClaw's visible model catalog.
- `snapshot/openclaw/openclaw.sanitized.json` - OpenClaw config with tokens and
  personal Telegram identifiers redacted.
- `snapshot/openclaw/ollama-provider-models.json` - OpenClaw Ollama provider
  model records.
- `snapshot/bin/ollama-wrapper` - local wrapper that syncs OpenClaw after
  Ollama model changes.
- `snapshot/bin/openclaw-local-model` - local model profile helper with Telegram
  identifiers redacted.
- `snapshot/scripts/openclaw_ollama_sync.py` - Ollama -> OpenClaw model catalog
  sync.
- `snapshot/scripts/ollama_hw_obsidian_logger.py` - Ollama hardware sampling
  logger.
- `snapshot/scripts/waybar-ai-usage.py` - Waybar AI usage indicator.
- `snapshot/systemd/` - relevant user service/timer units.
- `notes/` - curated architecture notes from Obsidian.

## What Is Excluded

- `~/.ollama` model blobs.
- Hugging Face caches.
- `/home/goringich/models` model weights and experiments.
- `~/.openclaw/secrets`, `~/.openclaw/sessions`, delivery queues, and runtime
  databases.
- `~/.codex/auth.json`, session JSONL files, and private conversation logs.
- Raw Telegram, OpenAI, Anthropic, Google, DeepSeek, OpenRouter, or gateway
  tokens.

## Current Shape

The local stack is layered:

```text
Codex CLI / OpenClaw / OpenHarness
  -> local tools and project workspaces
  -> Ollama and remote model providers
  -> Obsidian notes and system health logs
```

OpenClaw is the persistent assistant runtime. Ollama is the local model backend.
The wrapper and timer keep newly installed Ollama chat models discoverable by
OpenClaw.

See `INVENTORY.md` and `SECURITY.md` for the operational map and safety rules.
