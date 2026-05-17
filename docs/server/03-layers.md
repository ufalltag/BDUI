# Слои архитектуры

## 1. Domain — чистые контракты

Самый важный слой. Не зависит ни от кого. Все остальные слои зависят от него.

```
src/domain/
├── protocol.rs   ← константы версии
├── screen.rs     ← трейты Screen + ScreenRepository
├── models.rs     ← DTO для HTTP-ответов
└── ui.rs         ← типы компонентов (Component, StaticScreen…)
```

### Трейты (контракты)

```
                    ┌─────────────────────────────────┐
                    │          Screen (trait)          │
                    │                                  │
                    │  + id() → &'static str           │
                    │  + cache_key() → &'static str    │
                    │  + static_screen() → &StaticScreen│
                    │  + dynamic_data() → Value        │
                    │  + full_response_size() → usize  │
                    │  ─────────────────────────────── │
                    │  DEFAULT: full_response()        │  ← Template Method
                    │    = static_screen + dynamic_data│
                    └─────────────────────────────────┘
                                   △
                    ┌──────────────┼──────────────┐
                    │              │              │
             ┌──────┴──┐    ┌──────┴──┐    ┌──────┴──┐
             │ Profile │    │  Home   │    │ Catalog │  …
             └─────────┘    └─────────┘    └─────────┘
```

```
                    ┌──────────────────────────────────┐
                    │      ScreenRepository (trait)     │
                    │                                   │
                    │  + find(id) → Option<&dyn Screen> │
                    │  + all_ids() → Vec<&'static str>  │
                    └──────────────────────────────────┘
                                   △
                    ┌──────────────────────────────────┐
                    │          ScreenRegistry           │
                    │  HashMap<&'static str, Box<dyn>> │
                    └──────────────────────────────────┘
```

### Template Method в действии

```rust
// domain/screen.rs — алгоритм сборки ответа зафиксирован один раз:
fn full_response(&self) -> BduiFullResponse {
    BduiFullResponse {
        protocol_version: protocol::CURRENT,
        ui: UiParts {
            static_part: self.static_screen().clone(),  // ← реализует каждый экран
            dynamic:     self.dynamic_data(),           // ← реализует каждый экран
        },
        cache_key: self.cache_key().to_owned(),         // ← реализует каждый экран
    }
}

// infrastructure/screens/profile.rs — только данные, не алгоритм:
impl Screen for ProfileScreen {
    fn id(&self)            -> &'static str       { "profile" }
    fn cache_key(&self)     -> &'static str       { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn dynamic_data(&self)  -> Value              { json!({ "username": "…" }) }
    fn full_response_size(&self) -> usize         { *FULL_SIZE }
    // full_response() не переопределяется — используется дефолтный
}
```

---

## 2. Application — бизнес-логика

```
src/application/
└── screen_service.rs    ← ScreenService
```

Единственная обязанность `ScreenService` — принять `screen_id` и `client_cache_key`, и вернуть готовые байты. **Не знает про HTTP**, **не знает про конкретные экраны**.

```
                    ┌─────────────────────────────────────────┐
                    │              ScreenService               │
                    │                                          │
                    │  - repository: Arc<dyn ScreenRepository>│
                    │  ─────────────────────────────────────  │
                    │  + handle(screen_id, client_cache_key)   │
                    │      → Result<ScreenResult, ScreenError> │
                    │                                          │
                    │  + all_screen_ids() → Vec<&'static str> │
                    └─────────────────────────────────────────┘
```

### Логика `handle()`

```
handle(screen_id, client_cache_key)
         │
         ├─ repository.find(screen_id)  → None?  →  ScreenError::NotFound
         │
         ▼  screen: &dyn Screen
         │
         ├─ client_cache_key == None
         │       └──▶  First request
         │              serialize full_response()
         │              kind = First, saved = 0
         │
         ├─ client_cache_key == Some(key) AND key == screen.cache_key()
         │       └──▶  Cache Hit
         │              serialize BduiCacheHitResponse { dynamic_data() }
         │              saved = full_response_size - hit_bytes
         │              kind  = CacheHit
         │
         └─ client_cache_key == Some(key) AND key ≠ screen.cache_key()
                 └──▶  Cache Miss
                        serialize full_response()
                        kind = CacheMiss, saved = 0
```

---

## 3. Infrastructure — конкретные реализации

```
src/infrastructure/
├── hashing.rs             ← SHA-256 canonical hash
├── screen_registry.rs     ← ScreenRegistry: implements ScreenRepository
└── screens/
    ├── mod.rs             ← register_all() → ScreenRegistry
    ├── profile.rs         ← ProfileScreen: impl Screen
    ├── home.rs
    ├── settings.rs
    ├── catalog.rs
    ├── product.rs
    └── data/*.json        ← встроены в бинарь через include_str!()
```

### Жизненный цикл данных экрана

```
Компиляция:
  include_str!("data/profile.json")
            │
            ▼  строка в бинаре
  LazyLock<(StaticScreen, String)>
            │
            ├─ StaticScreen  ← serde_json::from_str()
            └─ cache_key     ← compute_cache_key(&static_screen)

Runtime (первое обращение):
  LazyLock инициализируется ровно один раз
  Все последующие обращения → &'static ссылка без аллокаций
```

### Builder-паттерн регистрации

```rust
// infrastructure/screens/mod.rs
pub fn register_all() -> ScreenRegistry {
    ScreenRegistry::new()
        .register(ProfileScreen)   // ← добавить экран = одна строка
        .register(HomeScreen)
        .register(SettingsScreen)
        .register(CatalogScreen)
        .register(ProductScreen)
}

// infrastructure/screen_registry.rs
pub fn register(mut self, screen: impl Screen + 'static) -> Self {
    self.screens.insert(screen.id(), Box::new(screen));
    self
}
```

---

## 4. Server — только HTTP

```
src/server/
├── mod.rs           ← build_router(AppState) → Router
├── state.rs         ← AppState { screen_service, metrics }
├── error.rs         ← AppError: ScreenNotFound | UnsupportedVersion
└── handlers/
    ├── screen.rs    ← GET /bdui/screen/:id
    ├── meta.rs      ← GET /bdui/meta
    └── metrics.rs   ← GET /metrics
```

Хендлер делает **только три вещи**:
1. Валидирует версию протокола
2. Вызывает `screen_service.handle()`
3. Записывает метрику

```rust
// server/handlers/screen.rs — упрощённо:
pub async fn handle(State(state), Path(screen_id), Query(params), headers) {
    validate_version(&headers)?;                      // 1. версия

    let result = state.screen_service                 // 2. логика
        .handle(&screen_id, params.cache_key.as_deref())
        .map_err(AppError::from)?;

    let (bytes, event) = result.into_event(screen_id, elapsed);
    state.metrics.record(event);                      // 3. метрики

    Ok((StatusCode::OK, JSON_CT, bytes))
}
```

### AppError — типобезопасные HTTP-ошибки

```
AppError::ScreenNotFound
    │
    ├─ статус:  404 NOT FOUND
    └─ тело:    { "error": "screen_not_found" }

AppError::UnsupportedVersion { client_version: 99 }
    │
    ├─ статус:  406 NOT ACCEPTABLE
    └─ тело:    { "error": "unsupported_protocol_version",
                  "client_version": 99,
                  "supported_versions": [1] }
```

---

## 5. Metrics — сквозная функциональность

```
src/metrics/
├── mod.rs       ← Metrics (Mutex<Inner>), MetricsSnapshot
└── event.rs     ← RequestEvent, RequestKind { First | CacheHit | CacheMiss }
```

```
Один запрос → один RequestEvent
                │
                ├─ screen_id:   "profile"
                ├─ kind:        CacheHit
                ├─ bytes_sent:  312
                ├─ bytes_saved: 1847
                └─ duration_ms: 0.041

GET /metrics → MetricsSnapshot
                │
                ├─ total_requests:        150
                ├─ cache_hit_rate_pct:    73.3
                ├─ total_bytes_saved:     218 400
                ├─ traffic_reduction_pct: 68.1
                └─ per_screen: { "profile": {...}, "home": {...} }
```
