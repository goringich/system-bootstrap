# repo-inventory

Generated: `2026-03-28T22:01:07+03:00`

Scan root: `/home/goringich`

## Summary

- total repos: `21`
- personal GitHub repos: `12`
- external upstream repos: `5`
- local-only repos: `4`
- other remotes: `0`

## Personal GitHub Repos

- `/home/goringich/Desktop/Obsidian` -> `git@github.com:goringich/Obsidian.git` -> branch `master` -> dirty `10`
- `/home/goringich/Desktop/elizabet` -> `git@github.com:goringich/elizabet.git` -> branch `develop` -> dirty `40`
- `/home/goringich/Desktop/hse/compilers/llvm-project` -> `git@github.com:goringich/llvm-project.git` -> branch `main` -> dirty `0`
- `/home/goringich/Desktop/hse` -> `git@github.com:goringich/-.git` -> branch `master` -> dirty `5`
- `/home/goringich/Desktop/otlichniy-ulov-docs` -> `git@github.com:goringich/otlichniy-ulov-docs.git` -> branch `master` -> dirty `0`
- `/home/goringich/Desktop/otlichniy-ulov` -> `git@github.com:goringich/otlichniy-ulov.git` -> branch `master` -> dirty `132`
- `/home/goringich/codex-orchestrator` -> `git@github.com:goringich/codex-orchestrator.git` -> branch `main` -> dirty `6`
- `/home/goringich/custom-cachyos-iso` -> `git@github.com:goringich/my-custom-cachyos-iso.git` -> branch `master` -> dirty `0`
- `/home/goringich/esp` -> `git@github.com:goringich/ESP32-P4-M3.git` -> branch `master` -> dirty `0`
- `/home/goringich/remote-windows` -> `git@github.com:goringich/remote-windows.git` -> branch `main` -> dirty `1`
- `/home/goringich/system-bootstrap` -> `git@github.com:goringich/system-bootstrap.git` -> branch `main` -> dirty `157`
- `/home/goringich/telegram-proxy-stack` -> `git@github.com:goringich/telegram-proxy-stack.git` -> branch `develop` -> dirty `0`

## External Upstream Repos

- `/home/goringich/Arch-Hyprland` -> `https://github.com/JaKooLit/Arch-Hyprland.git` -> branch `main` -> dirty `1`
- `/home/goringich/Hyprland-Dots` -> `https://github.com/JaKooLit/Hyprland-Dots.git` -> branch `main` -> dirty `8`
- `/home/goringich/esp/esp-idf` -> `https://github.com/espressif/esp-idf.git` -> branch `detached` -> dirty `0`
- `/home/goringich/teamviewer` -> `https://aur.archlinux.org/teamviewer.git` -> branch `master` -> dirty `4`
- `/home/goringich/yay` -> `https://aur.archlinux.org/yay.git` -> branch `master` -> dirty `0`

## Local-Only Repos

- `/home/goringich/Desktop/otlichny-ulov-game-ui` -> branch `main` -> dirty `0`
- `/home/goringich/dotfiles` -> branch `main` -> dirty `0`
- `/home/goringich/hyprland-nvidia-recovery-docs` -> branch `master` -> dirty `0`
- `/home/goringich/obsidian-3d-graph-controls` -> branch `feature/physics-controls` -> dirty `0`

## Restore Risks

- dirty personal repo: `/home/goringich/Desktop/Obsidian` -> `git@github.com:goringich/Obsidian.git` -> branch `master` -> dirty `10`
- dirty personal repo: `/home/goringich/Desktop/elizabet` -> `git@github.com:goringich/elizabet.git` -> branch `develop` -> dirty `40`
- dirty personal repo: `/home/goringich/Desktop/hse` -> `git@github.com:goringich/-.git` -> branch `master` -> dirty `5`
- dirty personal repo: `/home/goringich/Desktop/otlichniy-ulov` -> `git@github.com:goringich/otlichniy-ulov.git` -> branch `master` -> dirty `132`
- dirty personal repo: `/home/goringich/codex-orchestrator` -> `git@github.com:goringich/codex-orchestrator.git` -> branch `main` -> dirty `6`
- dirty personal repo: `/home/goringich/remote-windows` -> `git@github.com:goringich/remote-windows.git` -> branch `main` -> dirty `1`
- dirty personal repo: `/home/goringich/system-bootstrap` -> `git@github.com:goringich/system-bootstrap.git` -> branch `main` -> dirty `157`
- suspicious remote naming: `/home/goringich/Desktop/hse` -> `git@github.com:goringich/-.git` -> branch `master` -> dirty `5`

## Notes

- `personal-github` repos can be hydrated by `restore-my-system` without extra decisions.
- `external-upstream` repos should stay documented, but not treated as your personal source of truth.
- `local-only` repos are the main blockers for true 1:1 GitHub-backed restore until they get remotes or are intentionally retired.
- Bluetooth recovery for the onboard Foxconn `0489:e10a` adapter is part of the canonical restore path in `system-bootstrap` via `system/`, `configs/system-paths.txt`, and `docs/bluetooth-foxconn-e10a-runbook.md`.
