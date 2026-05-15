# system-control-catalog

## Control Score

- score: `43/100`
- lane: `red`

## Summary

- personal repos: `7`
- external repos: `0`
- local-only repos: `1`
- declared but not captured: `0`
- uncovered live paths: `88`
- promote next: `18`
- review later: `7`
- likely noise: `58`
- secret-risk files: `2`

## Local-Only Repos

- `/home/goringich/dotfiles` branch `main` dirty `0`

## Promote Next

- `.config/ags` -> Aylur shell layer should be either tracked or intentionally retired
- `.config/autostart` -> desktop startup intent should not stay implicit
- `.config/codex` -> Codex machine config needs explicit ownership and secret split
- `.config/niri` -> window manager experiments should be either tracked or removed from active surface
- `.config/quickshell` -> UI shell layer should be canonical or intentionally excluded
- `.config/shell` -> shell support layer should not drift outside source of truth
- `.config/zellij` -> terminal workspace identity is part of the personal environment
- `.local/bin/check-mic.sh` -> audio diagnostics helper should be part of the canonical mic workflow
- `.local/bin/claude-local` -> local Claude routing wrapper should be canonical if this flow is kept
- `.local/bin/claude-obsidian-sync` -> Claude transcript export should be part of the shared Obsidian capture workflow
- `.local/bin/copilot-obsidian-sync` -> Copilot transcript export should be part of the shared Obsidian capture workflow
- `.local/bin/easyeffects-start.sh` -> audio wrapper should be part of the canonical desktop audio layer
- `.local/bin/easyeffects` -> audio wrapper should be part of the canonical desktop audio layer
- `.local/bin/mic-rollback.sh` -> audio rollback helper should be restorable
- `.local/bin/oh` -> OpenHarness wrapper should be canonical if local-agent routing depends on it
- `.local/bin/ollama` -> Ollama wrapper should be canonical if local sync hooks depend on it
- `.local/bin/skif777-switch` -> controlled VPN switching helper should be tracked or intentionally retired
- `.local/bin/telegram-profile` -> multi-profile Telegram launcher is part of desktop identity

## Review Later

- `.config/Kvantum` -> Qt theming may belong in the canonical desktop identity
- `.config/htop` -> small but useful terminal behavior config
- `.config/lazygit` -> developer workflow config may deserve capture
- `.config/proxychains` -> network tooling config may matter for restore
- `.config/s-tui` -> hardware tooling config may matter if actively used
- `.local/bin/codex-api` -> Codex local API helper may deserve a dedicated tracked home
- `.local/bin/dev-control-api` -> local dev control API may deserve a dedicated tracked home

## Likely Noise

- `.config/QtProject.conf` -> Qt runtime cache-like state
- `.config/baloofileinformationrc` -> desktop indexing noise
- `.config/baloofilerc` -> desktop indexing noise
- `.config/cachyos-hello.json` -> distro helper state is usually not part of canonical identity
- `.config/cachyos` -> distro helper state is usually not part of canonical identity
- `.config/dolphinrc` -> package-provided file manager state is usually not part of canonical path
- `.config/filetypesrc` -> runtime association state is usually noisy
- `.config/gwenviewrc` -> runtime viewer state is usually noisy
- `.config/ibus` -> input framework runtime state
- `.config/pavucontrol.ini` -> audio mixer runtime state
- `.config/session` -> desktop runtime session state
- `.config/teamviewer` -> app-specific runtime state
- `.config/trashrc` -> trash metadata is not canonical
- `.config/x-cinnamon-xdg-terminals.list` -> desktop association noise
- `.config/xdg-terminals.list` -> desktop association noise
- `.config/yay` -> AUR helper runtime state
- `.local/bin/Telegram.codex-20260430-webkit.bak` -> backup Telegram wrapper should not count as canonical payload
- `.local/bin/Telegram.codex-20260430-webview.bak` -> backup Telegram wrapper should not count as canonical payload
- `.local/bin/debugpy-adapter` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/debugpy` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/futureagi-agentcc-host` -> downloaded tool binary should be restored by installer, not copied from local bin
- `.local/bin/github-mcp-server` -> downloaded tool binary should be restored by installer, not copied from local bin
- `.local/bin/httpx` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/ipython3` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/ipython` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/jlpm` -> tool shim should be restored by package manager, not copied from local bin
- `.local/bin/jsonpointer` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/jsonschema` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-console` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-dejavu` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-events` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-execute` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-kernelspec` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-kernel` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-labextension` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-labhub` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-lab` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-migrate` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-nbconvert` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-notebook` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-run` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-server` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-troubleshoot` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter-trust` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/jupyter` -> Python tool shims should be restored by package or venv, not copied from local bin
- `.local/bin/pybabel` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/pyjson5` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/send2trash` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/bin/wal` -> package-installed tool shim should be restored by package manager, not copied from local bin
- `.local/bin/wsdump` -> Python tool shim should be restored by package or venv, not copied from local bin
- `.local/share/applications/discord-working.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/discord.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/google-chrome-stable.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/google-chrome.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/gwenview-2.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/gwenview.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/libreoffice-2.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/libreoffice.desktop` -> desktop file duplication from package or app updates

## Declared But Not Yet Captured

- none

## Secret Risk Files

- `.config/codex/mcp-secrets.env`
- `.zsh_history`
