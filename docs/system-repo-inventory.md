# repo-inventory

Generated: `2026-04-25T04:05:55+03:00`

Scan root: `/home/goringich`

Repo scope: `system`

## Summary

- total repos: `9`
- personal GitHub repos: `8`
- external upstream repos: `0`
- local-only repos: `1`
- other remotes: `0`

## Personal GitHub Repos

- `/home/goringich/Desktop/Obsidian` -> `git@github.com:goringich/Obsidian.git` -> branch `master` -> dirty `25`
- `/home/goringich/__home_organized/scripts/obsidian-voice-vocab` -> `git@github.com:goringich/jJarvis-Translator-into-Obsidian.git` -> branch `main` -> dirty `0`
- `/home/goringich/__home_organized` -> `git@github.com:goringich/__home_organized.git` -> branch `master` -> dirty `7`
- `/home/goringich/codex-orchestrator` -> `git@github.com:goringich/codex-orchestrator.git` -> branch `main` -> dirty `7`
- `/home/goringich/custom-cachyos-iso` -> `git@github.com:goringich/my-custom-cachyos-iso.git` -> branch `master` -> dirty `0`
- `/home/goringich/hyprland-nvidia-recovery-docs` -> `git@github.com:goringich/hyprland-nvidia-recovery-docs.git` -> branch `master` -> dirty `0`
- `/home/goringich/obsidian-repo-mounts` -> `git@github.com:goringich/obsidian-repo-mounts.git` -> branch `main` -> dirty `0`
- `/home/goringich/system-bootstrap` -> `git@github.com:goringich/system-bootstrap.git` -> branch `codex/local-ai-stack-snapshot` -> dirty `199`

## External Upstream Repos


## Local-Only Repos

- `/home/goringich/dotfiles` -> branch `main` -> dirty `3`

## Restore Risks

- dirty personal repo: `/home/goringich/Desktop/Obsidian` -> `git@github.com:goringich/Obsidian.git` -> branch `master` -> dirty `25`
- dirty personal repo: `/home/goringich/__home_organized` -> `git@github.com:goringich/__home_organized.git` -> branch `master` -> dirty `7`
- dirty personal repo: `/home/goringich/codex-orchestrator` -> `git@github.com:goringich/codex-orchestrator.git` -> branch `main` -> dirty `7`
- dirty personal repo: `/home/goringich/system-bootstrap` -> `git@github.com:goringich/system-bootstrap.git` -> branch `codex/local-ai-stack-snapshot` -> dirty `199`

## Notes

- `personal-github` repos can be hydrated by `restore-my-system` without extra decisions.
- `external-upstream` repos should stay documented, but not treated as your personal source of truth.
- `local-only` repos are the main blockers for true 1:1 GitHub-backed restore until they get remotes or are intentionally retired.
- Bluetooth recovery for the onboard Foxconn `0489:e10a` adapter is part of the canonical restore path in `system-bootstrap` via `system/`, `configs/system-paths.txt`, and `docs/bluetooth-foxconn-e10a-runbook.md`.
