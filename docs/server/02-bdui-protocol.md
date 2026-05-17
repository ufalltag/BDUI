# BDUI Smart Caching Protocol

## Проблема

Классический BDUI отдаёт **полный JSON** при каждом запросе — включая неизменяемую структуру экрана. При тысячах запросов это огромное количество одинаковых байт.

```
Без кэширования:
  Запрос 1  →  { static: {layout, components…}, dynamic: {data…} }  ~2 KB
  Запрос 2  →  { static: {layout, components…}, dynamic: {data…} }  ~2 KB  ← static те же!
  Запрос N  →  { static: {layout, components…}, dynamic: {data…} }  ~2 KB
```

## Решение: разделение на static + dynamic

```
С умным кэшированием:
  Запрос 1  →  { static: {…}, dynamic: {…}, cache_key: "a1b2…" }   ~2 KB  (full)
  Запрос 2  →  { dynamic: {…} }                                      ~0.3 KB (hit!)
  Запрос N  →  { dynamic: {…} }                                      ~0.3 KB (hit!)
```

---

## Структура ответов

### Полный ответ (первый запрос или cache miss)

```json
{
  "protocol_version": 1,
  "cache_key": "9e4a1f3d...c2b8",
  "ui": {
    "static": {
      "screen_id": "profile",
      "layout": "ProfileScreenLayout",
      "navigation": { "tab_bar": false, "back_button": true, "title": "Profile" },
      "components": [
        { "type": "header", "id": "header", "props": { "back_button": true } },
        { "type": "avatar", "id": "avatar", "props": { "size": "60" } },
        { "type": "text",   "id": "username" },
        { "type": "button", "id": "edit_btn", "props": { "title": "Edit Profile" } }
      ]
    },
    "dynamic": {
      "username": { "text": "Tagir Fayrushin" },
      "avatar":   { "initials": "TF", "background_color": "#5856D6" }
    }
  }
}
```

### Cache-hit ответ (повторный запрос с совпавшим ключом)

```json
{
  "protocol_version": 1,
  "ui": {
    "dynamic": {
      "username": { "text": "Tagir Fayrushin" },
      "avatar":   { "initials": "TF", "background_color": "#5856D6" }
    }
  }
}
```

> Нет `cache_key` → клиент знает, что это cache hit. Статика не передаётся.

---

## Сценарии взаимодействия

### Первый запрос

```
Client                                    Server
  │                                          │
  │  GET /bdui/screen/profile                │
  │─────────────────────────────────────────▶│
  │                                          │  1. cache_key в запросе отсутствует
  │                                          │  2. строит BduiFullResponse
  │                                          │  3. серializует static + dynamic
  │  200 OK                                  │
  │  { protocol_version, cache_key,          │
  │    ui: { static, dynamic } }             │
  │◀─────────────────────────────────────────│
  │                                          │
  │  Клиент сохраняет:                       │
  │  • cache_key → UserDefaults              │
  │  • static    → UserDefaults              │
```

### Cache Hit

```
Client                                    Server
  │                                          │
  │  GET /bdui/screen/profile                │
  │  ?cache_key=9e4a1f3d...                  │
  │─────────────────────────────────────────▶│
  │                                          │  1. client_key == server_key ✓
  │                                          │  2. строит только BduiCacheHitResponse
  │                                          │  3. serializes только dynamic
  │  200 OK                                  │
  │  { protocol_version,                     │
  │    ui: { dynamic } }                     │
  │◀─────────────────────────────────────────│
  │                                          │
  │  Клиент берёт static из UserDefaults     │
  │  Клиент применяет новые dynamic данные   │
```

### Cache Miss (устаревший ключ)

```
Client                                    Server
  │                                          │
  │  GET /bdui/screen/profile                │
  │  ?cache_key=СТАРЫЙ_КЛЮЧ                  │
  │─────────────────────────────────────────▶│
  │                                          │  1. client_key ≠ server_key ✗
  │                                          │  2. Layout изменился на сервере
  │                                          │  3. строит BduiFullResponse
  │  200 OK                                  │
  │  { protocol_version, NEW_cache_key,      │
  │    ui: { static, dynamic } }             │
  │◀─────────────────────────────────────────│
  │                                          │
  │  Клиент обновляет кэш новым ключом       │
  │  и новой статикой                        │
```

---

## Вычисление cache_key

```
StaticScreen (typed Rust struct)
       │
       ▼
serde_json::to_value()   ← сериализация в Value
       │
       ▼
canonicalize()           ← рекурсивная сортировка ключей объектов
       │
       ▼  { "components": [...], "layout": "...", "navigation": {...} }
       │   ^ ключи отсортированы на каждом уровне вложенности
       │
       ▼
SHA-256(canonical_json_string)
       │
       ▼
hex::encode()            ← 64-символьный hex
       │
       ▼
"9e4a1f3dc2b8..."        ← cache_key
```

**Зачем канонизация?** JSON объекты не имеют гарантированного порядка ключей. Без сортировки `{"a":1,"b":2}` и `{"b":2,"a":1}` дали бы разные хэши — даже при одинаковой структуре.

```
В коде (src/infrastructure/hashing.rs):

fn canonicalize(value: Value) -> Value {
    match value {
        Value::Object(map) => {
            let mut entries: Vec<_> = map.into_iter()
                .map(|(k, v)| (k, canonicalize(v)))
                .collect();
            entries.sort_by(|(a, _), (b, _)| a.cmp(b));   ← сортировка
            Value::Object(entries.into_iter().collect())
        }
        Value::Array(arr) => Value::Array(arr.into_iter().map(canonicalize).collect()),
        other => other,
    }
}
```

---

## Версионирование протокола

Клиент отправляет заголовок `X-BDUI-Version: 1`. Сервер проверяет его и возвращает `406 Not Acceptable` если версия не поддерживается.

```
Клиент с версией 1:
  GET /bdui/screen/profile
  X-BDUI-Version: 1
  ──────────────────▶  сервер: 1 ∈ SUPPORTED=[1] ✓  →  200 OK

Клиент с версией 99:
  GET /bdui/screen/profile
  X-BDUI-Version: 99
  ──────────────────▶  сервер: 99 ∉ SUPPORTED=[1] ✗  →  406
  {
    "error": "unsupported_protocol_version",
    "client_version": 99,
    "supported_versions": [1]
  }
```

Список поддерживаемых версий в `src/domain/protocol.rs`:

```rust
pub const CURRENT: u8 = 1;
pub const SUPPORTED: &[u8] = &[1];   // добавить 2 сюда при следующем breaking change
```
