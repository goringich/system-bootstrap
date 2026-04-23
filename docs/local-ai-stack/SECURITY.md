# Security Notes

This snapshot is intentionally not a full backup.

## Do Not Commit

- Model weights and quantized blobs.
- OpenClaw secrets and session stores.
- Codex auth files and session JSONL.
- Telegram tokens and user IDs.
- OpenAI, Anthropic, Google, DeepSeek, OpenRouter, Hugging Face, or gateway
  tokens.
- Runtime databases, delivery queues, and raw conversation mirrors.

## Sanitization Performed

- OpenClaw gateway token source is kept, token values are not.
- Telegram personal and group identifiers are replaced with placeholders.
- `openai-whisper-api` API keys are redacted.
- Secret file paths are represented as placeholders where useful.

## Operational Risk

OpenClaw currently reports local small-model/tooling security warnings. Those
warnings are configuration risks, not publication blockers for this sanitized
snapshot. The raw runtime config should still be treated as sensitive because it
describes routing, agents, channels, and local trust boundaries.

## Recovery Use

Use this snapshot to reconstruct the structure and automation, not to restore
credentials. Credentials must be re-created through local secret stores.
