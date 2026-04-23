# Inventory

## Runtime Surfaces

- Codex CLI: interactive coding/system agent.
- Codex orchestrator: queued background Codex tasks.
- OpenClaw: persistent local gateway, Telegram routing, project agents.
- Ollama: local inference backend and model registry.
- OpenHarness: separate local harness on top of Ollama.
- Obsidian: long-term memory, architecture notes, conversation mirrors, system
  health logs.

## Local Model Inventory

The current exact `ollama list` output is stored in:

- `snapshot/ollama-models.txt`

The current OpenClaw model view is stored in:

- `snapshot/openclaw/openclaw-models.txt`

As of this snapshot, the important local chat models are:

- `qwen3.6:35b-a3b`
- `minimax-m2.7:ud-iq3_s`
- `qwen3-coder-next:q8_0`
- `mdq100/qwen3.5-coder:35b`
- `gpt-oss:20b`
- `qwen2.5:1.5b`

`nomic-embed-text:latest` is present locally but is an embedding model, so it is
not treated as an OpenClaw chat assistant model.

## Sync Flow

`snapshot/bin/ollama-wrapper` shadows `/usr/local/bin/ollama` through
`~/.local/bin/ollama`.

After successful `ollama pull`, `ollama create`, `ollama rm`, `ollama cp`, or
`ollama push`, it runs:

```bash
/home/goringich/__home_organized/scripts/openclaw_ollama_sync.py
openclaw gateway restart
```

The periodic fallback is:

- `snapshot/systemd/openclaw-ollama-sync.service`
- `snapshot/systemd/openclaw-ollama-sync.timer`

The timer refreshes catalogs without forcing a gateway restart every interval.

## Important Local Paths

- `~/.openclaw/openclaw.json`
- `~/.openclaw/agents/*/agent/models.json`
- `~/.local/bin/openclaw-local-model`
- `~/.local/bin/ollama`
- `~/__home_organized/scripts/openclaw_ollama_sync.py`
- `~/__home_organized/scripts/ollama_hw_obsidian_logger.py`
- `~/__home_organized/scripts/waybar-ai-usage.py`
- `~/Desktop/Obsidian/ИИ/`
- `~/codex-orchestrator`

## GitHub Placement

This snapshot lives under `system-bootstrap/docs/local-ai-stack/` because this
repo is the machine-level source for recoverable local architecture.
