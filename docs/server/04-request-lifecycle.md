# Жизненный цикл запроса

## Полный путь от TCP до байт в ответе

```
TCP socket (0.0.0.0:3000)
         │
         ▼
   tokio::net::TcpListener
         │
         ▼
   axum::serve                         ← Tokio async runtime
         │
         ▼
   Router::route("/bdui/screen/:id")   ← match URL
         │
         ▼
   Extractors (параллельно):
     ├─ State<AppState>               ← Arc clone (дёшево)
     ├─ Path<String>                  ← screen_id из URL
     ├─ Query<ScreenParams>           ← cache_key из ?cache_key=…
     └─ HeaderMap                     ← все заголовки запроса
         │
         ▼
   handlers::screen::handle()
         │
         ├─ validate_version(&headers)
         │       │
         │       ├─ нет X-BDUI-Version → Ok(())  (backward compat)
         │       ├─ 1 ∈ SUPPORTED      → Ok(())
         │       └─ 99 ∉ SUPPORTED     → Err(AppError::UnsupportedVersion)
         │                                   → 406 + JSON
         │
         ▼  Instant::now()  ← старт таймера
         │
         ▼
   screen_service.handle(screen_id, client_cache_key)
         │
         ├─ repository.find(screen_id)
         │       └─ None → Err(ScreenError::NotFound)
         │                     → AppError::ScreenNotFound → 404 + JSON
         │
         ▼  screen: &dyn Screen
         │
         ├─ client_cache_key == None          → First
         │       serialize screen.full_response()
         │
         ├─ client_key == screen.cache_key()  → CacheHit
         │       serialize BduiCacheHitResponse { dynamic_data() }
         │       calculate bytes_saved
         │
         └─ client_key ≠ screen.cache_key()  → CacheMiss
                 serialize screen.full_response()
         │
         ▼  ScreenResult { bytes, kind, bytes_saved }
         │
         ▼  elapsed = start.elapsed()
         │
         ├─ tracing::info!(screen, kind, sent, saved, ms)
         │
         ├─ metrics.record(RequestEvent { … })
         │       └─ Mutex::lock() → обновить счётчики → unlock()
         │
         ▼
   (StatusCode::OK, [("content-type", "application/json")], bytes)
         │
         ▼
   axum serializes response → TCP write
```

---

## Что происходит внутри LazyLock при первом запросе

```
Первое обращение к screen.cache_key() или static_screen()
         │
         ▼
   LazyLock::force(&STATIC)
         │
         ├─ Ещё не инициализирован? → вызвать closure один раз:
         │       parse_static(
         │           include_str!("data/profile.json"),   ← данные в бинаре
         │           "profile.json"
         │       )
         │       │
         │       ├─ serde_json::from_str() → StaticScreen
         │       └─ compute_cache_key(&screen) → String (SHA-256 hex)
         │
         └─ Уже инициализирован? → вернуть &'static ref немедленно
         │
         ▼
   &'static (StaticScreen, String)
```

> `LazyLock` гарантирует инициализацию **ровно один раз**, даже при конкурентных запросах. После инициализации — это просто dereference без синхронизации.

---

## Диаграмма состояний `cache_key`

```
                    ┌───────────────────────────────┐
                    │  Клиент не знает о screen      │
                    └──────────────┬────────────────┘
                                   │ GET /bdui/screen/profile
                                   │ (без cache_key)
                                   ▼
                    ┌───────────────────────────────┐
                    │  Сервер: First Request         │
                    │  Возвращает: static + dynamic  │
                    │  + cache_key = "9e4a…"         │
                    └──────────────┬────────────────┘
                                   │
                                   ▼
                    ┌───────────────────────────────┐
                    │  Клиент сохраняет cache_key    │
                    │  Клиент сохраняет static       │
                    └──────────────┬────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
                    │  GET /bdui/screen/profile?cache_key=9e4a…│
                    └──────────────┬──────────────────────────┘
                                   │
                     ┌─────────────┴─────────────┐
                     │                           │
              key совпал                   key устарел
                     │                           │
                     ▼                           ▼
         ┌─────────────────┐          ┌──────────────────┐
         │   Cache HIT     │          │   Cache MISS     │
         │  static пропущен│          │  новый static    │
         │  только dynamic │          │  новый cache_key │
         └─────────────────┘          └────────┬─────────┘
                                               │
                                               ▼
                                    Клиент обновляет кэш
```

---

## Замеры производительности

Хендлер замеряет только **серверное время** (от получения запроса до формирования ответа):

```
Instant::now()          ← сразу после валидации версии
        │
        │   repository.find()      ~0 нс  (HashMap lookup)
        │   screen.dynamic_data()  ~1 мкс (json! macro evaluation)
        │   serde_json::to_vec()   ~10 мкс (serialization)
        │
duration = elapsed       ← до передачи bytes в TCP

Типичные значения:
  First request:   0.1–0.5 мс
  Cache hit:       0.05–0.2 мс   ← меньше данных → быстрее сериализация
  Cache miss:      0.1–0.5 мс
```

Сетевое время, время TCP, TLS — **не включены** в `duration_ms` метрику намеренно: они вне контроля сервера.
