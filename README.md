# system-bootstrap

Полный bootstrap этой системы в формате "одна команда": пакеты, AUR, сервисы и пользовательские конфиги.

## Быстрый старт

```bash
git clone <YOUR_REPO_URL> system-bootstrap
cd system-bootstrap
./install.sh
```

## Control Tower

После restore и во время system-shaping работы:

```bash
syscontrol
syscontrol --compact
syscontrol --tui
syscontrol --sync-docs
```

`syscontrol` показывает:
- что уже captured в `system-bootstrap` или personal GitHub repos
- что заявлено для snapshot, но ещё не попало в git payload
- что живёт вообще вне personal git coverage
- где есть secret-risk следы
- в `--tui` режиме даёт навигацию по секциям, focus-режимы и refresh прямо из терминала

## Один вход

```bash
cd system-bootstrap
./bin/restore-my-system --dry-run --skip-aur
./bin/restore-my-system --skip-aur
./bin/restore-my-system --profile minimal --dry-run
```

`restore-my-system`:
- применяет `system-bootstrap`
- затем дотягивает твои GitHub-репозитории из `configs/repos.txt`
- профиль `full` использует расширенный manifest `configs/repos-all.txt`
- затем пишет restore audit в `~/.local/state/system-bootstrap/restore-report.txt`
- не трогает dirty-репозитории при обновлении

## Codex Orchestrator

Локальный orchestration layer для фоновых Codex worker-задач:
- `~/.local/bin/codex-agent-enqueue`
- `~/.local/bin/codex-agent-run`
- `~/.local/bin/codex-agent-status`
- `~/.config/systemd/user/codex-agent-orchestrator.timer`
- manager prompt: `~/.config/codex-orchestrator/manager-prompt.txt`

Runtime и логи лежат вне home root:
- `__home_organized/runtime/codex-orchestrator`
- `__home_organized/logs/codex-orchestrator`
- `__home_organized/artifacts/codex-orchestrator`

## Профили

- `full` — всё, что описано в `system-bootstrap`
- `desktop` — профиль по умолчанию, сейчас пропускает AUR на первом проходе
- `minimal` — облегчённый bring-up без AUR и без systemd service enable, с урезанным repo manifest

## Что ставится

- `manifests/pacman-explicit-non-system.txt` — все явно установленные пакеты кроме системной базы
- `manifests/aur-explicit.txt` — AUR пакеты
- `manifests/enabled-services.txt` — включенные systemd-сервисы
- `home/` — снимок пользовательских конфигов, тем, скриптов и `.local/bin`
- `system/` — снимок выбранных system-level overlay файлов из `/etc`
- `configs/system-paths.txt` — список system-level путей, которые нужно capture/restore вместе с `system/`
- `configs/repos.txt` — репозитории, которые нужно автоматически дотянуть после bootstrap
- `configs/repos-all.txt` — полный manifest всех личных GitHub-репозиториев, найденных на основной машине
- `configs/repos-minimal.txt` — урезанный manifest для минимального подъёма
- `configs/profiles/*.sh` — профили one-command bootstrap
- `docs/repo-inventory.md` — автоматически собранная карта всех локальных git-репозиториев с классификацией
- `docs/bluetooth-foxconn-e10a-runbook.md` — machine-specific Bluetooth recovery and bring-up notes

## Обновить снимок с текущей машины

```bash
./scripts/capture-state.sh
```

После `capture-state.sh` также обновляется:

- `docs/repo-inventory.md`
- `configs/repos-all.txt`

Snapshot hygiene:
- `configs/rsync-excludes.txt` blocks secrets, shell history, browser/runtime state, caches and generated wallpaper artifacts from entering `home/`.
- `scripts/validate-repo.sh` is the local/CI gate for shell syntax, manifest format, obvious secret patterns and the dry-run restore entrypoint.
- `.github/workflows/ci.yml` runs the same validation on GitHub Actions.

## Опции установки

```bash
./install.sh --skip-services
./install.sh --skip-aur
./install.sh --skip-configs
./install.sh --skip-system-overlay
./install.sh --skip-packages
./install.sh --dry-run
./install.sh --no-backup
```

## Safety Rails

- перед наливкой `home/` делается backup текущих файлов в `~/.system-bootstrap-backups/`
- `--dry-run` показывает, что будет выполнено, без применения изменений
- `TARGET_HOME=/path/to/test-home ./install.sh --dry-run` позволяет прогонять восстановление на отдельной директории
- `clone-repos.sh` пропускает dirty-репозитории и не делает force update
- `restore-my-system --profile minimal` даёт более осторожный первый проход
- после host restore пишется отчёт `~/.local/state/system-bootstrap/restore-report.txt` с пробелами по repo hydration, ключевым путям и сервисам

## Ограничения

- Скрипт ориентирован на Arch/CachyOS.
- Системные пакеты ядра/базы исключаются из default-манифеста.
- Секреты (`~/.ssh`, токены, браузерные профили) в репозиторий не копируются.
