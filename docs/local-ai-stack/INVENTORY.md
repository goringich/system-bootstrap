# Inventory

## Runtime Surfaces

- Codex CLI: interactive coding/system agent.
- Codex orchestrator: queued background Codex tasks.
- Codex bootstrap and retrieval layer: `AGENTS.md`, `manager-prompt.txt`,
  `llms.txt`, `llms-full.txt`, `obsidian-context-pack.py`,
  `agent-context-bootstrap.py`, and the aligned Obsidian notes that together
  form Codex's entry into the machine-wide RAG.
- OpenClaw: persistent local gateway, Telegram routing, project agents.
- Ollama: local inference backend and model registry.
- OpenHarness: separate local harness on top of Ollama.
- Open WebUI: browser UI on `http://127.0.0.1:3030` for local Ollama chat,
  file/document chat, RAG, and future tool/function workflows.
- Obsidian: long-term memory, architecture notes, conversation mirrors, system
  health logs.
- Local AI Control: local command and Rofi launcher that summarizes
  Ollama/OpenClaw/GPU state and writes the Obsidian AI dashboard.

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
- `~/__home_organized/scripts/local-ai-control.py`
- `~/__home_organized/scripts/obsidian-context-pack.py`
- `~/__home_organized/scripts/agent-context-bootstrap.py`
- `~/__home_organized/llms.txt`
- `~/__home_organized/llms-full.txt`
- `~/.local/bin/local-ai-control`
- `~/.local/share/applications/local-ai-control.desktop`
- `~/Desktop/Obsidian/ИИ/Local AI Control Center.md`
- `~/Desktop/Obsidian/ИИ/AI система на этом ПК — полная архитектура 2026-04-24.md`
- `~/__home_organized/runtime/local-ai/open-webui/compose.yaml`
- `~/__home_organized/scripts/local-ai/open-webui`
- `~/.local/bin/open-webui-local`
- `~/.local/share/applications/open-webui-local.desktop`
- `~/Desktop/Obsidian/ИИ/Open WebUI Local.md`
- `~/Desktop/Obsidian/ИИ/`
- `~/codex-orchestrator`

## Open WebUI

Open WebUI is installed as the practical browser layer on top of the existing
Ollama service. It is intentionally local-only by default.

Runtime:

- URL: `http://127.0.0.1:3030`
- container: `local-ai-open-webui`
- image: `ghcr.io/open-webui/open-webui:main`
- compose: `~/__home_organized/runtime/local-ai/open-webui/compose.yaml`
- data volume: `local-ai-open-webui-data`
- Docker restart policy: `unless-stopped`

Model wiring:

- Ollama base URL: `http://127.0.0.1:11434`
- default model: `gpt-oss:20b`
- task model: `gpt-oss:20b`
- pinned models:
  - `gpt-oss:20b`
  - `mdq100/qwen3.5-coder:35b`
  - `qwen3.6:27b`
  - `qwen3.6:35b-a3b`
- RAG embedding engine: `ollama`
- RAG embedding model: `nomic-embed-text:latest`
- hybrid RAG search: enabled
- retrieval query generation: enabled
- RAG system context: enabled
- web search: disabled by default

Commands:

```bash
open-webui-local start
open-webui-local status
open-webui-local logs
open-webui-local stop
open-webui-local open
```

The Rofi/Super+D launcher is `Open WebUI Local`.

## Local AI Control

The control surface is intentionally lightweight and does not install a new
model runner or web application. It keeps the current architecture centered on
Ollama, OpenClaw, OpenHarness, and Obsidian.

Commands:

```bash
local-ai-control status
local-ai-control dashboard
local-ai-control json
ollama-profile-manager rag-bench
```

The dashboard records:

- installed Ollama models
- selected local model roles: heavy coding, balanced coding, fast draft, RAG
  embeddings
- GPU and active-model state
- OpenClaw status summary
- candidate next-layer tools researched for the stack: Open WebUI, AnythingLLM,
  Qdrant, and R2R
- the fixed retrieval gate now lives at
  `~/__home_organized/scripts/local-ai/rag-bench.py` with questions in
  `~/__home_organized/runtime/local-ai/rag-bench/questions.json`

Current role map from `local-ai-control doctor` on `2026-05-12`:

- heavy coding: `qwen3-coder-next:q8_0`
- balanced coding: `mdq100/qwen3.5-coder:35b`
- fast draft: `gpt-oss:20b`
- embeddings: `nomic-embed-text:latest`

## Documentation Contract

- If local AI architecture, model roles, prompts, bootstrap paths, or RAG settings change, update the matching Obsidian notes in the same task.
- If Codex bootstrap, retrieval, or system documentation behavior changes, treat that as the same local RAG contract and update the matching Obsidian notes plus prompt/bootstrap files in the same task.
- Keep the live prompt copy, tracked mirror, and Obsidian architecture notes aligned.

## GitHub Placement

This snapshot lives under `system-bootstrap/docs/local-ai-stack/` because this
repo is the machine-level source for recoverable local architecture.
