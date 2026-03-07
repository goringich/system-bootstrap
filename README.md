# system-bootstrap

Полный bootstrap этой системы в формате "одна команда": пакеты, AUR, сервисы и пользовательские конфиги.

## Быстрый старт

```bash
git clone <YOUR_REPO_URL> system-bootstrap
cd system-bootstrap
./install.sh
```

## Что ставится

- `manifests/pacman-explicit-non-system.txt` — все явно установленные пакеты кроме системной базы
- `manifests/aur-explicit.txt` — AUR пакеты
- `manifests/enabled-services.txt` — включенные systemd-сервисы
- `home/` — снимок пользовательских конфигов, тем, и скриптов

## Обновить снимок с текущей машины

```bash
./scripts/capture-state.sh
```

## Опции установки

```bash
./install.sh --skip-services
./install.sh --skip-aur
./install.sh --skip-configs
./install.sh --skip-packages
./install.sh --dry-run
./install.sh --no-backup
```

## Safety Rails

- перед наливкой `home/` делается backup текущих файлов в `~/.system-bootstrap-backups/`
- `--dry-run` показывает, что будет выполнено, без применения изменений
- `TARGET_HOME=/path/to/test-home ./install.sh --dry-run` позволяет прогонять восстановление на отдельной директории

## Ограничения

- Скрипт ориентирован на Arch/CachyOS.
- Системные пакеты ядра/базы исключаются из default-манифеста.
- Секреты (`~/.ssh`, токены, браузерные профили) в репозиторий не копируются.
