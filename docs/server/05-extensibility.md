# Расширяемость

## Как добавить новый экран

Добавление нового экрана требует изменений **только в двух местах** и не трогает ни одну существующую строку логики.

### Шаг 1 — Создать JSON-дескриптор

```
src/infrastructure/screens/data/cart.json
```

```json
{
  "screen_id": "cart",
  "layout": "CartScreenLayout",
  "navigation": {
    "tab_bar": true,
    "tab_index": 2,
    "back_button": false,
    "title": "Cart"
  },
  "components": [
    { "type": "header",    "id": "header",    "props": { "title": "My Cart" } },
    { "type": "cart_list", "id": "items" },
    { "type": "button",    "id": "checkout_btn", "props": { "title": "Checkout" } }
  ]
}
```

### Шаг 2 — Создать файл экрана

```
src/infrastructure/screens/cart.rs
```

```rust
use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/cart.json"), "cart.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&CartScreen.full_response()).unwrap().len());

pub struct CartScreen;

impl Screen for CartScreen {
    fn id(&self)                -> &'static str       { "cart" }
    fn cache_key(&self)         -> &'static str       { &STATIC.1 }
    fn static_screen(&self)     -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize             { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        json!({
            "items": [
                { "id": "prod_3", "name": "USB-C Hub 7-in-1", "price": "$49.99", "qty": 2 }
            ],
            "total": "$99.98",
            "item_count": 1
        })
    }
}
```

### Шаг 3 — Зарегистрировать

```rust
// src/infrastructure/screens/mod.rs — одна строка:
mod cart;   // ← добавить

pub fn register_all() -> ScreenRegistry {
    ScreenRegistry::new()
        .register(ProfileScreen)
        .register(HomeScreen)
        .register(SettingsScreen)
        .register(CatalogScreen)
        .register(ProductScreen)
        .register(CartScreen)        // ← добавить
}
```

**Всё.** `GET /bdui/screen/cart` начнёт работать. `GET /bdui/meta` автоматически включит `cart` в список. Метрики подхватятся сами.

```
Изменённые файлы при добавлении экрана:
  ✅  src/infrastructure/screens/data/cart.json   (новый)
  ✅  src/infrastructure/screens/cart.rs           (новый)
  ✅  src/infrastructure/screens/mod.rs            (одна строка)
  
  ❌  domain/      не трогаем
  ❌  application/ не трогаем
  ❌  server/      не трогаем
  ❌  metrics/     не трогаем
```

---

## Как добавить новую версию протокола

Предположим: в версии 2 мы хотим добавить поле `ttl_seconds` в ответ.

### Шаг 1 — Обновить константы

```rust
// src/domain/protocol.rs
pub const CURRENT: u8 = 2;                  // ← было 1
pub const SUPPORTED: &[u8] = &[1, 2];       // ← добавить 2, оставить 1
```

### Шаг 2 — Добавить новую модель

```rust
// src/domain/models.rs
#[derive(Serialize)]
pub struct BduiFullResponseV2 {
    pub protocol_version: u8,
    pub cache_key: String,
    pub ttl_seconds: u32,           // ← новое поле
    pub ui: UiParts,
}
```

### Шаг 3 — Ветвить логику в сервисе или хендлере

```rust
// src/server/handlers/screen.rs
let client_version = parse_version(&headers);

let response_bytes = if client_version >= 2 {
    // V2: добавляем TTL
    let v2 = BduiFullResponseV2 { ttl_seconds: 300, ..base };
    serde_json::to_vec(&v2)
} else {
    // V1: прежний формат
    serde_json::to_vec(&base)
};
```

**Ключевое:** старые V1-клиенты продолжают работать без изменений — `SUPPORTED = [1, 2]`.

---

## Как добавить новый эндпоинт

Пример: `GET /bdui/screen/:id/preview` — возвращает только статику без динамики.

### Шаг 1 — Создать хендлер

```rust
// src/server/handlers/preview.rs
pub async fn handle(
    State(state): State<AppState>,
    Path(screen_id): Path<String>,
) -> Result<impl IntoResponse, AppError> {
    let ids = state.screen_service.all_screen_ids();
    if !ids.contains(&screen_id.as_str()) {
        return Err(AppError::ScreenNotFound);
    }
    // Доступ к репозиторию через screen_service или добавить метод
    Ok(Json(json!({ "screen_id": screen_id, "preview": "…" })))
}
```

### Шаг 2 — Добавить в роутер

```rust
// src/server/mod.rs
pub fn build_router(state: AppState) -> Router {
    Router::new()
        .route("/bdui/screen/{screen_id}",         get(handlers::screen::handle))
        .route("/bdui/screen/{screen_id}/preview", get(handlers::preview::handle))  // ←
        .route("/bdui/meta",                       get(handlers::meta::handle))
        .route("/metrics",                         get(handlers::metrics::handle))
        .with_state(state)
}
```

---

## Матрица изменений

| Задача | domain | application | infrastructure | server | metrics |
|---|:---:|:---:|:---:|:---:|:---:|
| Добавить экран | — | — | ✏️ | — | — |
| Новая версия протокола | ✏️ const | — | — | ✏️ handler | — |
| Новый эндпоинт | — | — | — | ✏️ handler + route | — |
| Новая метрика | — | — | — | — | ✏️ |
| Изменить UI-тип (Component) | ✏️ | — | — | — | — |
| Заменить хранилище экранов | — | — | ✏️ new impl | — | — |

Принцип Open/Closed в действии: большинство изменений — это **добавление**, а не модификация.
