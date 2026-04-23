Если цель именно **самая мощная локальная open-weight модель для кодинга и архитектуры** на твоём железе **96 GB RAM + 16 GB VRAM**, то мой вывод такой:

## Лучший выбор

**`Qwen3-Coder-Next`** - это сейчас самый сильный кандидат под твой сценарий. Qwen прямо позиционирует его как модель **для coding agents и local development**, и указывает, что у него **80B total / 3B active parameters**, с упором на длинные задачи, tool use, recovery after failures и агентный coding workflow. Это очень хорошо совпадает с тем, что тебе нужно не просто “писать функции”, а держать в голове архитектуру, несколько файлов, рефакторинг и сложные цепочки действий. ([Hugging Face](https://huggingface.co/Qwen/Qwen3-Coder-Next "Qwen/Qwen3-Coder-Next · Hugging Face"))

## Почему не `qwen3.5-coder:35b` как основной

`Qwen3.5-35B-A3B` тоже очень сильный и свежий, и официально выпущен только в конце февраля 2026 года как часть новой линейки Qwen3.5. Но это скорее **очень хороший универсальный/сильный баланс**, а не максимальный локальный упор именно в агентный coding. Для “тяжёлого” кодинга и архитектурных задач я бы ставил `Qwen3-Coder-Next` выше. ([GitHub](https://github.com/QwenLM/Qwen3.5 "GitHub - QwenLM/Qwen3.5: Qwen3.5 is the large language model series developed by Qwen team, Alibaba Cloud. · GitHub"))

## Почему не `gpt-oss:20b`

`gpt-oss-20b` - хорошая модель, но OpenAI описывает её как вариант для **lower latency, local or specialized use cases**, тогда как старшая логика в линейке уходит в `gpt-oss-120b`. При этом `gpt-oss-120b` требует около **80 GB memory**, а `gpt-oss-20b` - около **16 GB memory**. То есть на твоём ПК `20b` - это удобный локальный компромисс, но не “самая продвинутая локальная coding-модель”, если сравнивать именно с актуальным `Qwen3-Coder-Next`. ([OpenAI](https://openai.com/index/introducing-gpt-oss/ "Introducing gpt-oss | OpenAI"))

## Почему не `DeepSeek-Coder-V2` как главный выбор

`DeepSeek-Coder-V2` всё ещё серьёзная модель: у неё заявлены сильные code benchmark results, до **128K context**, и версия `236B / 21B active`. Но это старая волна по сравнению с тем, что сейчас продвигает Qwen в локальном agentic coding. Lite-версия у DeepSeek удобнее по ресурсам, но это уже компромисс, а не максимум для твоего железа. ([GitHub](https://github.com/deepseek-ai/DeepSeek-Coder-V2 "GitHub - deepseek-ai/DeepSeek-Coder-V2: DeepSeek-Coder-V2: Breaking the Barrier of Closed-Source Models in Code Intelligence · GitHub"))

## Важная поправка по твоему тесту

То, что ты написал про **only CPU mode в начале**, очень важно. Это объясняет, почему по логам у тебя одна и та же модель могла выглядеть “слабой” или “не такой уж GPU-oriented”. В таком режиме ты фактически тестировал не только модель, но и стратегию размещения слоёв/kv-cache/offload. Поэтому твой прошлый вывод по `qwen3-coder-next:q8_0` нельзя считать окончательным при нормальной GPU-настройке. Сам по себе факт, что модель была CPU-heavy, не означает, что она хуже как LLM. ([Hugging Face](https://huggingface.co/Qwen/Qwen3-Coder-Next "Qwen/Qwen3-Coder-Next · Hugging Face"))

## Что бы я рекомендовал тебе реально

Для твоего ПК я бы выстроил так:

**1. Основная модель для серьёзного coding/architecture:**  
`Qwen3-Coder-Next`

**2. Запасной стабильный вариант:**  
`Qwen3.5-35B-A3B`

**3. Быстрый вспомогательный вариант:**  
`gpt-oss:20b`

Такой набор закрывает три режима:

- максимум качества для кода и архитектуры
    
- хороший стабильный fallback
    
- быстрый дешёвый рабочий инструмент для простых задач ([Hugging Face](https://huggingface.co/Qwen/Qwen3-Coder-Next "Qwen/Qwen3-Coder-Next · Hugging Face"))
    

## Практический вывод именно под твоё железо

С твоими **96 GB RAM** ты можешь тянуть тяжёлые модели через RAM, но **16 GB VRAM** всё равно остаётся главным ограничением. Поэтому тебе нужна не просто “самая большая” модель, а модель, которая **лучше всего переживает hybrid CPU+GPU execution**. Из актуальных вариантов именно `Qwen3-Coder-Next` выглядит самым разумным кандидатом на роль топовой локальной coding-модели, а `Qwen3.5-35B-A3B` - самым разумным резервом. ([Hugging Face](https://huggingface.co/Qwen/Qwen3-Coder-Next "Qwen/Qwen3-Coder-Next · Hugging Face"))

Если хочешь, следующим сообщением я могу уже без теории дать тебе **конкретный топ-3 в формате**:

- какая модель для **Ollama**
    
- какая для **llama.cpp**
    
- какой **quant** брать на **16 GB VRAM + 96 GB RAM**
    
- какой **context** ставить, чтобы не убивать систему.

## См. также

- [[ИИ/Модели/Локальные LLM/Index|Локальные LLM Index]]
- [[ИИ/Модели/Локальные LLM/Ollama/Index|Ollama Index]]
- [[ИИ/Модели/Локальные LLM/Ollama/Бенч локальных моделей Ollama на моем железе|Бенч локальных моделей Ollama на моем железе]]
- [[ИИ/Модели/Локальные LLM/Ollama/Лог запуска локальных моделей|Лог запуска локальных моделей]]
