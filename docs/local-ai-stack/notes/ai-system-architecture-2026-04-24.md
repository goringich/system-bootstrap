# AI система на этом ПК — полная архитектура 2026-04-24

См. также:

- [[OpenClaw/OpenClaw]]
- [[Разница GPT-5 и GPT-5-CODEX]]
- [[System/System Blueprint/08 Codex Agent Orchestrator]]
- [[System/System Blueprint/14 Codex Conveyor Workflow]]
- [[System/System Blueprint/16 Codex Configuration Map]]

## Коротко

На этом ПК нет одной "магической ИИшки". Здесь уже собран **многослойный AI-стек**, где разные системы решают разные классы задач:

- `Codex` = главный интерактивный coding-agent с сильным reasoning и доступом к локальной среде
- `codex-orchestrator` = очередь и automation layer для фоновых Codex-задач
- `OpenClaw` = постоянно живущий assistant runtime с gateway, Telegram и project-agents
- `Ollama` = локальный inference backend и хост локальных моделей
- `OpenHarness` / `oh` = отдельный локальный harness-CLI поверх `Ollama`
- `ohmo` = personal-agent workspace поверх OpenHarness, сейчас тоже переведён в local-only профиль
- `Obsidian` = долговременная память, документация, conversation mirror и архитектурный слой

То есть архитектура уже не "один чат", а:

```text
Пользователь
  -> Codex CLI / queue / OpenClaw Telegram / OpenHarness
  -> инструменты и локальная файловая система
  -> локальные и подписочные модели
  -> Obsidian как долговременная память и архитектурный журнал
```

## 1. Уровни системы

### A. Reasoning / Agent Surface

#### Codex

- путь конфигурации: `~/.codex/config.toml`
- модель по умолчанию: `gpt-5.5`
- режим: interactive coding agent
- доступ:
  - локальные файлы
  - shell
  - MCP
  - web search
- роль:
  - сложные инженерные задачи
  - системная настройка
  - работа по репозиториям
  - документирование архитектуры

#### OpenClaw

- runtime path: `~/.openclaw`
- node package: `~/.local/lib/node_modules/openclaw`
- gateway: `http://127.0.0.1:18789`
- transport: local gateway + Telegram
- роль:
  - постоянно работающий ассистент
  - multi-agent routing
  - project-agents
  - background / daemon-style access

#### OpenHarness

- repo: `/home/goringich/OpenHarness`
- virtualenv: `~/.openharness-venv`
- CLI links:
  - `~/.local/bin/oh`
  - `~/.local/bin/ohmo`
  - `~/.local/bin/openharness`
- config:
  - `~/.openharness/settings.json`
  - `~/.openharness/credentials.json`
- роль:
  - отдельный local-only coding harness
  - альтернативный CLI agent поверх локальных моделей
  - не заменяет Codex и OpenClaw, а добавляет ещё один локальный рабочий контур

### B. Orchestration Layer

#### codex-orchestrator

- repo: `/home/goringich/codex-orchestrator`
- назначение:
  - очередь задач для Codex
  - manager prompt
  - worker execution
  - launchers и systemd user automation
- runtime paths:
  - `~/__home_organized/runtime/codex-orchestrator/queue`
  - `~/__home_organized/runtime/codex-orchestrator/claims`
  - `~/__home_organized/runtime/codex-orchestrator/done`
  - `~/__home_organized/runtime/codex-orchestrator/failed`
  - `~/__home_organized/logs/codex-orchestrator`
  - `~/__home_organized/artifacts/codex-orchestrator`

### C. Model Backend Layer

#### Ollama

- local endpoint: `http://127.0.0.1:11434/v1`
- роль:
  - отдаёт локальные модели по OpenAI-compatible API
  - питает OpenClaw
  - теперь питает и OpenHarness

Проверенные локальные модели на 2026-04-24:

- `mdq100/qwen3.5-coder:35b`
- `qwen3.6:35b-a3b`
- `qwen3-coder-next:q8_0`
- `gpt-oss:20b`
- `qwen2.5:1.5b`
- `minimax-m2.7:ud-iq3_s`
- `nomic-embed-text:latest`

### D. Memory / Documentation Layer

#### Obsidian

- vault: `/home/goringich/Desktop/Obsidian`
- роль:
  - human-readable memory
  - архитектурные notes
  - conversation mirrors
  - system and GPU health
  - AI knowledge base

Главные AI-related зоны vault:

- `codex-conversations/`
- `ИИ/OpenClaw/`
- `System/System Blueprint/`
- `System/System Health/`
- `System/GPU Health/`

## 2. Что где является source of truth

- `Codex runtime/config`:
  - `~/.codex/config.toml`
  - `~/.codex/auth.json`
  - `~/.codex/memories/`

- `Codex automation`:
  - `/home/goringich/codex-orchestrator`

- `OpenClaw runtime/config`:
  - `~/.openclaw/openclaw.json`

- `OpenHarness runtime/config`:
  - `~/.openharness/settings.json`
  - `~/.openharness/credentials.json`

- `ohmo personal-agent workspace`:
  - `~/.ohmo/gateway.json`
  - `~/.ohmo/state.json`
  - `~/.ohmo/soul.md`
  - `~/.ohmo/user.md`

- `долговременная архитектурная память`:
  - Obsidian vault

## 3. Как сейчас реально течёт работа

### Codex path

```text
Пользователь -> Codex CLI
            -> shell/filesystem/MCP/web
            -> правки в repo или system config
            -> conversation export в Obsidian
            -> архитектурные заметки в Obsidian
```

### Codex conveyor path

```text
Пользователь -> codex-agent-enqueue / codex queue-*
            -> codex-orchestrator
            -> очередь worker-задач
            -> runtime/logs/artifacts
            -> при необходимости фиксация в repo
```

### OpenClaw path

```text
Telegram / local gateway
  -> OpenClaw gateway
  -> agent router
  -> project-agent
  -> Ollama models
  -> ответы / tasks / sessions
  -> mirror в Obsidian/OpenClaw
```

### OpenHarness path

```text
Терминал -> oh / ohmo
        -> profile ollama-local
        -> Ollama OpenAI-compatible endpoint
        -> local model
        -> ответ / tool-use / local coding workflow
```

## 4. Текущее состояние OpenClaw

По состоянию на этот проход:

- gateway жив на `127.0.0.1:18789`
- Telegram канал включён и отвечает
- project-agents уже заведены
- основная локальная модель по умолчанию: `ollama/mdq100/qwen3.5-coder:35b`
- fallback / fast lane тоже сидят на локальных Ollama-моделях

Это означает, что **persistent assistant layer уже построен**.

OpenClaw здесь решает задачу "ассистент живёт постоянно и доступен из каналов", а не задачу "лучший coding CLI".

## 5. Текущее состояние Codex

- Codex остаётся главным high-trust engineering agent
- использует MCP:
  - `openaiDeveloperDocs`
  - `playwright`
  - `context7`
  - `github`
  - `filesystem`
  - `figma`
- есть multi-agent support
- есть js_repl
- есть live web search

То есть **Codex = основной сильный инженерный агент**, а не daemon assistant.

## 6. Текущее состояние OpenHarness

OpenHarness установлен и переведён на local-only сценарий.

### Что сделано

- repo cloned: `/home/goringich/OpenHarness`
- Python package установлен в `~/.openharness-venv`
- React TUI dependencies поставлены
- CLI binary links созданы в `~/.local/bin`
- профиль `ollama-local` активирован
- `ohmo` workspace инициализирован
- `ohmo` gateway profile переведён с `codex` на `ollama-local`
- из `~/.openharness/credentials.json` убрана привязка к Codex subscription
- вместо этого оставлен profile-specific local placeholder credential для `Ollama`

### Текущий рабочий профиль

- active profile: `ollama-local`
- base URL: `http://127.0.0.1:11434/v1`
- model by default: `mdq100/qwen3.5-coder:35b`
- allowed local models:
  - `mdq100/qwen3.5-coder:35b`
  - `qwen3.6:35b-a3b`
  - `qwen3-coder-next:q8_0`
  - `gpt-oss:20b`
  - `qwen2.5:1.5b`
  - `minimax-m2.7:ud-iq3_s`
  - `nomic-embed-text:latest`

### Что проверено

- `oh auth status` -> `ollama-local` = `ready`
- `oh --dry-run -p 'reply with exactly local-ok'` -> readiness `ready`
- live run:

```text
oh -p 'reply with exactly local-ok'
-> local-ok
```

### Нюанс upstream

В `oh --dry-run` сейчас есть странность: profile берётся правильный (`ollama-local`), но поле `provider` отображается как `dashscope`. Это выглядит как display/runtime-id bug в upstream, потому что:

- база URL правильная
- активный профиль правильный
- live request к локальному `Ollama` проходит

То есть **конфиг рабочий, но в OpenHarness есть косметический баг отображения провайдера**.

## 7. Как компоненты не пересекаются, а дополняют друг друга

### Codex

Использовать когда нужно:

- сильное reasoning
- тяжёлая инженерная работа
- работа по репозиториям
- системная настройка
- internet-backed research

### codex-orchestrator

Использовать когда нужно:

- очередь фоновых задач
- повторяемый conveyor workflow
- worker automation

### OpenClaw

Использовать когда нужно:

- Telegram / daemon assistant
- project routing
- persistent sessions
- long-lived personal assistant behavior

### OpenHarness

Использовать когда нужно:

- отдельный локальный CLI harness
- локальные модели без подписочного backend
- быстрые local-only эксперименты
- ещё один terminal agent поверх `Ollama`

## 8. Ключевая архитектурная мысль

Система уже устроена так:

```text
Codex = premium engineering brain
codex-orchestrator = Codex automation + queue
OpenClaw = always-on assistant runtime
Ollama = local model backend
OpenHarness = secondary local-only harness over Ollama
Obsidian = long-term memory + architecture graph
```

То есть:

- **не надо пытаться превратить OpenHarness в замену Codex**
- **не надо пытаться превратить Codex в daemon-мессенджерного ассистента**
- **не надо пытаться превратить OpenClaw в основной IDE coding agent**

Сильная сторона текущей машины именно в том, что роли уже можно развести.

## 9. Риски и долги

- OpenClaw security audit сейчас сам предупреждает, что маленькие локальные модели с tool access требуют более жёсткого sandbox и web-deny posture
- OpenClaw сейчас местами работает с `exec security=full`, это удобно, но опасно
- OpenHarness upstream ещё сырее, чем Codex, и его стоит считать дополнительным инструментом, а не canonical control plane
- sandbox этой среды не видит локальный loopback `Ollama`, поэтому часть live-проверок отсюда приходится делать вне sandbox
- `codex-orchestrator` repo уже локально грязный и не относится полностью к этому проходу; менять его без отдельной задачи не стоит

## 10. Практическое правило использования

Если коротко, рабочая стратегия такая:

- нужен лучший инженерный агент -> `Codex`
- нужна очередь задач -> `codex-orchestrator`
- нужен daemon / Telegram / project-router -> `OpenClaw`
- нужен local-only terminal agent на локальных моделях -> `OpenHarness`
- нужно понять, как всё устроено и что уже делалось -> `Obsidian`

## 11. Что считать canonical описанием AI-системы

Эта заметка теперь должна быть главным обзором всей AI-архитектуры машины.

Детали раскрываются в специализированных notes:

- по Codex и conveyor -> `System Blueprint`
- по OpenClaw -> `ИИ/OpenClaw/*`
- по разговорам и истории -> `codex-conversations/`
- по системной устойчивости -> `System Health` и `GPU Health`
