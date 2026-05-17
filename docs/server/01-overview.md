# Server Architecture Overview

## Общая идея

Сервер реализует **BDUI smart-caching protocol**: разделяет ответ на статическую часть (структура UI — никогда не меняется) и динамическую часть (данные — меняются при каждом запросе). Клиент кэширует статику и при повторных запросах получает только динамику.

---

## Слои архитектуры

```
┌─────────────────────────────────────────────────────────────┐
│                        main.rs                               │
│           wire-up: создаёт зависимости, запускает сервер      │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   server/    │ │  application/│ │   metrics/   │
│  HTTP слой   │ │  use-cases   │ │ наблюдаемость │
└──────┬───────┘ └──────┬───────┘ └──────────────┘
       │                │
       └───────┬─────────┘
               │ depends on
               ▼
┌──────────────────────────────────────────────────┐
│                    domain/                        │
│   трейты, модели, константы — ноль зависимостей   │
└──────────────────────────────────────────────────┘
               ▲
               │ implements
┌──────────────────────────────────────────────────┐
│                 infrastructure/                   │
│   ScreenRegistry, 5 экранов, SHA-256 хэширование  │
└──────────────────────────────────────────────────┘
```

### Правило зависимостей

```
server  ──→  application  ──→  domain  ←──  infrastructure
```

- Стрелка = «знает о»
- `domain` не знает ни о ком — это чистые контракты
- `infrastructure` знает о `domain` (реализует трейты), но не о `server` и `application`
- `server` и `application` знают о `domain`, но не знают друг о друге напрямую

---

## Файловая структура

```
src/
├── main.rs                               ← точка входа, сборка зависимостей
│
├── domain/                               ← чистые контракты и типы данных
│   ├── mod.rs
│   ├── protocol.rs                       ← CURRENT=1, SUPPORTED=[1]
│   ├── screen.rs                         ← трейты Screen + ScreenRepository
│   ├── models.rs                         ← DTO: BduiFullResponse, BduiCacheHitResponse…
│   └── ui.rs                             ← Component, StaticScreen, NavigationConfig
│
├── application/                          ← бизнес-логика (use cases)
│   ├── mod.rs
│   └── screen_service.rs                 ← ScreenService: cache hit/miss/first
│
├── infrastructure/                       ← конкретные реализации
│   ├── mod.rs
│   ├── hashing.rs                        ← SHA-256 canonical hash
│   ├── screen_registry.rs                ← HashMap impl ScreenRepository
│   └── screens/
│       ├── mod.rs                        ← register_all() builder
│       ├── profile.rs                    ← ProfileScreen: impl Screen
│       ├── home.rs
│       ├── settings.rs
│       ├── catalog.rs
│       ├── product.rs
│       └── data/                         ← *.json встроены через include_str!()
│
├── metrics/                              ← сквозная функциональность
│   ├── mod.rs                            ← Metrics, MetricsSnapshot
│   └── event.rs                          ← RequestEvent, RequestKind
│
└── server/                               ← только HTTP: роутинг, парсинг, ответы
    ├── mod.rs                            ← build_router(AppState) → Router
    ├── state.rs                          ← AppState {screen_service, metrics}
    ├── error.rs                          ← AppError: IntoResponse
    └── handlers/
        ├── screen.rs                     ← GET /bdui/screen/:id
        ├── meta.rs                       ← GET /bdui/meta
        └── metrics.rs                    ← GET /metrics
```

---

## Паттерны проектирования

| Паттерн | Где применяется |
|---|---|
| **Repository** | `ScreenRepository` трейт + `ScreenRegistry` реализация |
| **Strategy** | `Screen` трейт — каждый экран подключаемая стратегия генерации данных |
| **Template Method** | `full_response()` по умолчанию в `Screen` трейте собирает ответ из `static_screen()` + `dynamic_data()` |
| **Builder** | `ScreenRegistry::new().register(A).register(B)` |
| **Service Layer** | `ScreenService` инкапсулирует всю логику cache hit/miss |

---

## Эндпоинты

| Метод | Путь | Описание |
|---|---|---|
| `GET` | `/bdui/screen/:id` | Полный ответ или cache-hit ответ |
| `GET` | `/bdui/screen/:id?cache_key=…` | Только динамика если ключ совпал |
| `GET` | `/bdui/meta` | Версия протокола, список экранов |
| `GET` | `/metrics` | Статистика запросов |
