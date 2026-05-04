# system-control-catalog

## Control Score

- score: `58/100`
- lane: `red`

## Summary

- personal repos: `7`
- external repos: `0`
- local-only repos: `1`
- declared but not captured: `2`
- uncovered live paths: `72`
- promote next: `7`
- review later: `5`
- likely noise: `35`
- secret-risk files: `3`

## Local-Only Repos

- `/home/goringich/dotfiles` branch `main` dirty `3`

## Promote Next

- `.config/ags` -> Aylur shell layer should be either tracked or intentionally retired
- `.config/autostart` -> desktop startup intent should not stay implicit
- `.config/codex` -> Codex machine config needs explicit ownership and secret split
- `.config/niri` -> window manager experiments should be either tracked or removed from active surface
- `.config/quickshell` -> UI shell layer should be canonical or intentionally excluded
- `.config/shell` -> shell support layer should not drift outside source of truth
- `.config/zellij` -> terminal workspace identity is part of the personal environment

## Review Later

- `.config/Kvantum` -> Qt theming may belong in the canonical desktop identity
- `.config/htop` -> small but useful terminal behavior config
- `.config/lazygit` -> developer workflow config may deserve capture
- `.config/proxychains` -> network tooling config may matter for restore
- `.config/s-tui` -> hardware tooling config may matter if actively used

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
- `.local/share/applications/discord-working.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/discord.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/google-chrome-stable.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/google-chrome.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/gwenview-2.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/gwenview.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/libreoffice-2.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/libreoffice.desktop` -> desktop file duplication from package or app updates
- `.local/share/applications/unzip-10.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-11.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-2.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-3.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-4.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-5.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-6.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-7.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-8.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip-9.desktop` -> generated or duplicate desktop entry noise
- `.local/share/applications/unzip.desktop` -> generated or duplicate desktop entry noise

## Declared But Not Yet Captured

- `.local/bin/claude-local` -> declared-not-captured
- `.local/bin/ollama` -> declared-not-captured

## Secret Risk Files

- `.config/codex/mcp-secrets.env`
- `.config/codex/mcp-secrets.example.env`
- `.zsh_history`
