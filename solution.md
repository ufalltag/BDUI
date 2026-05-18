### 🔍 Проблема

Существующая система BDUI (Backend-Driven UI) подразумевает, что интерфейс приложения описывается JSON-структурой, которую клиент (в нашем случае iOS-приложение) получает от бэкенда.
Каждый запрос к BDUI-эндпоинту возвращает полный JSON-описание экрана — включая и статические, и динамические части интерфейса.

Такая архитектура имеет существенный недостаток:

* Возникает высокая нагрузка на сеть,
* Увеличивается время отклика приложения,
* Бэкенд и CDN постоянно передают одни и те же данные (например, статические layout-описания), которые почти никогда не меняются.

Многие люди кэширует просто json структуру, но это зачастую не сильно снижает нагрузку на сеть

### 💡 Решение: “умное кэширование” BDUI

Ключевая идея — разделить BDUI-структуру на статическую и динамическую части, а также ввести единый кэш-протокол между бекендом и нативом (iOS).

Такое кэширование позволяет:

* Передавать по сети только изменившиеся (динамические) части,
* Уменьшить размер BDUI JSON в несколько раз,
* Сократить сетевую нагрузку и задержки,
* Упростить логику на стороне клиента (iOS).

## ⚙️ Протокол кэширования

### 1. Структура BDUI-ответа

Бэкенд теперь возвращает BDUI в следующем формате:
{
"ui": {
"static": {
// Описание неизменяемых элементов интерфейса
},
"dynamic": {
// Описание элементов, зависящих от данных
}
},
"cache_key": "a1b2c3d4" // Хэш статической части
}
* static — JSON-блок с описанием постоянной структуры экрана (layout, компоненты, иерархия).
* dynamic — JSON-блок, содержащий изменяемые данные (например, текст, контент, список карточек).
* cache_key — уникальный хэш, вычисляемый по статической части (`static`), который однозначно идентифицирует версию статического UI.

---

### 2. Работа клиента (iOS)

1. При первом запросе на экран клиент не передаёт кэш-ключ.
   GET /bdui/screen/home
   → Сервер возвращает полный BDUI (`static` + `dynamic`) и кэш-ключ.
2. Клиент сохраняет у себя cache_key для данного экрана.
3. При повторном открытии экрана клиент передаёт этот ключ:
   GET /bdui/screen/home?cache_key=a1b2c3d4
4. Сервер проверяет, актуален ли кэш:

    * Если ключ совпадает, сервер возвращает только динамическую часть:
      { "ui": { "dynamic": { ... } } }
* Если ключ не совпадает (изменился layout или логика), сервер возвращает полный BDUI и новый cache_key.

---

### 3. Логика на бэкенде

1. Каждый BDUI-эндпоинт описывает конкретный экран.
2. При генерации BDUI сервер:

    * Разделяет данные на static и dynamic,
    * Вычисляет cache_key как хэш от `static`-части (например, SHA256).
3. При получении запроса с параметром cache_key:

    * Сравнивает его с актуальным,
    * Возвращает либо только dynamic, либо полный JSON.

---
---

### 🧠 Пример использования

1. Первый запрос:
   GET /bdui/screen/profile
   Ответ:
   {
   "ui": {
   "static": { "layout": "ProfileScreenLayout" },
   "dynamic": { "username": "Tagir" }
   },
   "cache_key": "9e4a"
   }
2. Повторный запрос:
   GET /bdui/screen/profile?cache_key=9e4a
   Ответ (если layout не изменился):
   {
   "ui": {
   "dynamic": { "username": "Tagir Fayrushin" }
   }
   }

---

## 🛡️ Пункт 10 — Обработка ошибок и инвалидация кэша

### Проблемы, которые решаем

| Сценарий | Без защиты | С защитой |
|---|---|---|
| Клиент отправляет устаревший `cache_key` | Данные рассинхронизируются | Сервер возвращает полный ответ |
| Локальный кэш повреждён / отсутствует `static` | Приложение крашится | Инвалидация + повторный запрос |
| Layout сервера обновился | Клиент видит старый UI | Новый `cache_key` → полный ответ |
| Кэш устарел (прошло >24 часов) | Старые данные без обновления | TTL инвалидирует кэш автоматически |
| Пользователь хочет принудительное обновление | Нет механизма | Pull-to-refresh / `forceRefresh()` |

---

### Что реализовано

#### Сервер (Rust): заголовок `X-BDUI-Cache-Status`

Каждый ответ `/bdui/screen/{id}` теперь несёт заголовок, явно указывающий результат кэш-проверки:

```
X-BDUI-Cache-Status: first   — первый запрос, кэша нет
X-BDUI-Cache-Status: hit     — ключ совпал, отдана только динамика
X-BDUI-Cache-Status: miss    — ключ устарел, отдан полный ответ
```

Клиент может использовать этот заголовок для аналитики, отладки и принятия решений об UI. Пример: показать баннер «Layout обновлён» при `miss`.

```
curl http://localhost:3000/bdui/screen/profile -v
< X-BDUI-Cache-Status: first

curl "http://localhost:3000/bdui/screen/profile?cache_key=<key>" -v
< X-BDUI-Cache-Status: hit
```

---

#### iOS: TTL-инвалидация в `BDUICache`

`BDUICache` теперь сохраняет временну́ю метку при каждом `update()` и умеет проверять устаревание:

```swift
cache.isExpired(for: "profile", maxAge: 24 * 3600)  // true / false
```

Правила TTL:
- Метка отсутствует → `isExpired = true` (нет кэша = устарел)
- `maxAge = 0` → всегда `true` (форс-режим)
- `invalidate()` удаляет метку вместе с остальными данными

---

#### iOS: `forceRefresh` в `BDUIScreenLoader`

`BDUIScreenLoader.load(screenId:forceRefresh:)` принимает флаг принудительного обновления. При `forceRefresh = true` или истёкшем TTL локальный кэш инвалидируется **до** запроса, что гарантирует отправку запроса без `cache_key`:

```
load(screenId:, forceRefresh: true)
  → cache.invalidate()
  → fetch(cachedKey: nil)          ← сервер вернёт full response
  → cache.update(newKey, newStatic)
```

Протокол `BDUIScreenLoaderProtocol` обновлён, удобная одноаргументная версия доступна через extension:

```swift
loader.load(screenId: "profile")               // обычный вызов
loader.load(screenId: "profile", forceRefresh: true)  // принудительный
```

---

#### iOS: `forceRefresh()` в `BDUIScreenPresenter`

Презентер предоставляет публичный метод для принудительного обновления:

```swift
presenter.forceRefresh()   // инвалидирует кэш, запрашивает full response
presenter.didTapRetry()    // обычный повтор (без инвалидации кэша)
```

Отличие `forceRefresh` от `didTapRetry`: retry использует кэшированный ключ если он есть, forceRefresh всегда идёт за полным ответом.

---

#### iOS: Pull-to-refresh в `BDUIScreenViewController`

`UIRefreshControl` добавлен в `scrollView`. Жест "потянуть вниз" вызывает `presenter.forceRefresh()` — пользователь явно запрашивает свежие данные в обход кэша.

```
Пользователь тянет вниз
  → RefreshControl заканчивает анимацию
  → presenter.forceRefresh()
  → ActivityIndicator показывает загрузку
  → Сервер возвращает актуальный full response
  → Layout перестраивается если static изменился
```

---

### Диаграмма принятия решений при загрузке

```
load(screenId, forceRefresh)
        │
        ├─ forceRefresh == true ──────────────────┐
        │                                         │
        ├─ cache.isExpired(maxAge: 24h) == true ──┤
        │                                         ▼
        │                               cache.invalidate()
        │                               storedKey = nil
        │                                         │
        └─ кэш актуален ──────────────────────────┤
                                                  │
                                  fetch(cachedKey: storedKey)
                                                  │
                              ┌───────────────────┴───────────────┐
                              │                                   │
                        isCacheHit                          Full response
                              │                                   │
                  cachedStatic exists?              cache.update(key, static, ts)
                              │                    return ScreenData
                    ┌─────────┴────────┐
                    │                  │
                   yes                 no
                    │                  │
          return ScreenData    cache.invalidate()
          (local static +      retry load (forceRefresh: false)
           server dynamic)
```

---

### Тесты, добавленные в пункте 10

**SPM (`swift test`):**
- `test_forceRefresh_ignoresCachedKey` — при `forceRefresh` ключ не отправляется серверу
- `test_forceRefresh_invalidatesCacheBeforeFetch` — кэш инвалидируется до запроса
- `test_isExpired_withNoTimestamp_returnsTrue` — без метки кэш считается устаревшим
- `test_isExpired_afterUpdate_returnsFalse` — сразу после update кэш свежий
- `test_isExpired_afterInvalidate_returnsTrue` — invalidate удаляет метку
- `test_isExpired_withZeroMaxAge_returnsTrue` — maxAge=0 всегда инвалидирует
- `test_isExpired_differentScreensAreIndependent` — TTL независим для каждого экрана

**App (Xcode):**
- `test_forceRefresh_passesForceRefreshTrue` — presenter передаёт флаг в loader
- `test_viewDidLoad_doesNotPassForceRefresh` — обычный load не форсирует обновление

---

## ⚡ Пункт 11 — Дифференциальные обновления (dynamic_key / DynamicHit)

### Проблема

После пункта 10 у нас было два уровня кэширования:
1. **Full** — нет кэша или устаревший `cache_key`, сервер отдаёт всё
2. **CacheHit** — `cache_key` совпал, сервер отдаёт только динамику

Но даже при CacheHit клиент получает динамические данные по сети, хотя они могли не измениться с предыдущего запроса. Если пользователь открывает один и тот же экран несколько раз за короткий промежуток времени — сервер всё равно передаёт JSON с динамикой.

### Решение: третий уровень — DynamicHit

Вводим `dynamic_key` — SHA-256 хэш динамических данных экрана. Клиент хранит оба ключа и отправляет оба в запросе. Если ничего не изменилось — сервер возвращает только ключи (нулевой контент).

---

### Три уровня оптимизации

```
Клиент                             Сервер
  │                                   │
  ├─ GET /bdui/screen/profile         │
  │   (без cache_key)                 │
  │                                   ├─ Level 0: First
  │ ◄── full response ────────────────┤  { ui: {static, dynamic}, cache_key, dynamic_key }
  │                                   │
  ├─ GET /bdui/screen/profile         │
  │   ?cache_key=abc123               │
  │                                   ├─ Level 1: CacheHit (static unchanged)
  │ ◄── cache hit ────────────────────┤  { ui: {dynamic}, dynamic_key }
  │                                   │
  ├─ GET /bdui/screen/profile         │
  │   ?cache_key=abc123               │
  │   &dynamic_key=dyn456             │
  │                                   ├─ Level 2: DynamicHit (nothing changed)
  │ ◄── dynamic hit ──────────────────┤  { cache_key, dynamic_key }  ← нет "ui"
  │                                   │
```

| Уровень | Условие | Ответ сервера | Байт (примерно) |
|---|---|---|---|
| Full (First/Miss) | Нет ключа или `cache_key` устарел | static + dynamic | ~5 KB |
| CacheHit | `cache_key` совпал | только dynamic | ~500 B |
| DynamicHit | `cache_key` + `dynamic_key` совпали | только ключи | ~100 B |

---

### Сервер (Rust)

#### Новые поля в протоколе (`src/domain/models.rs`)

Все три типа ответа теперь несут `dynamic_key`:

```rust
pub struct BduiFullResponse {
    pub protocol_version: u8,
    pub ui: UiParts,
    pub cache_key: String,
    pub dynamic_key: String,   // новое
}

pub struct BduiCacheHitResponse {
    pub protocol_version: u8,
    pub dynamic_key: String,   // новое
    pub ui: DynamicOnly,
}

pub struct BduiDynamicHitResponse {   // новый тип
    pub protocol_version: u8,
    pub cache_key: String,
    pub dynamic_key: String,
}
```

#### Логика в `ScreenService` (`src/application/screen_service.rs`)

```
client_cache_key совпал?
    ├─ нет → Full response (First / CacheMiss)
    └─ да  → вычислить dynamic_key текущих данных
                 │
                 client_dynamic_key совпал?
                     ├─ нет → CacheHit (отдать dynamic + dynamic_key)
                     └─ да  → DynamicHit (отдать только ключи)
```

#### Метрики (`src/metrics/mod.rs`)

`RequestKind::DynamicHit` добавлен во все счётчики:
- `Inner`: `dynamic_hit_count`, `dynamic_hit_bytes`, `dynamic_hit_ms`
- `ScreenStats`: поле `dynamic_hits`
- `MetricsSnapshot`: поле `dynamic_hit: TypeStats`
- `cache_hit_rate_pct` теперь учитывает и CacheHit, и DynamicHit

#### Заголовок ответа

```
X-BDUI-Cache-Status: first        — первый запрос
X-BDUI-Cache-Status: miss         — cache_key устарел
X-BDUI-Cache-Status: hit          — cache_key совпал, dynamic изменился
X-BDUI-Cache-Status: dynamic_hit  — оба ключа совпали, ничего не изменилось
```

---

### iOS (Swift)

#### `BDUIServerResponse` (`BDUIModels.swift`)

`ui` стал опциональным (при DynamicHit сервер не возвращает `"ui"`), добавлен `dynamicKey`:

```swift
public struct BDUIServerResponse: Decodable {
    public let ui: UIContent?       // nil → DynamicHit
    public let cacheKey: String?    // nil → CacheHit
    public let dynamicKey: String?  // всегда присутствует при hit/dynamic_hit

    public var isCacheHit: Bool   { ui != nil && cacheKey == nil }
    public var isDynamicHit: Bool { ui == nil }
}
```

`ScreenData` получил поле `dynamicKey: String`.

#### `BDUICache` (`BDUICache.swift`)

Кэш теперь хранит динамические данные между запросами:

```swift
cache.cachedDynamicKey(for: screenId)    // → String?
cache.cachedDynamic(for: screenId)       // → JSONValue?
cache.updateDynamic(dynamicKey:dynamic:for:)  // при CacheHit
cache.update(..., dynamicKey:, dynamic:)      // при Full response
cache.invalidate(for:)                   // удаляет и статику, и динамику
```

#### `BDUIClientProtocol` (`BDUIClient.swift`)

```swift
func fetch(screenId: String, cachedKey: String?, dynamicKey: String?) async throws -> BDUIServerResponse
```

`buildURL()` добавляет `?cache_key=...&dynamic_key=...` если оба ключа есть.

#### `BDUIScreenLoader` (`BDUIScreenLoader.swift`)

Логика загрузки теперь обрабатывает три ветки:

```
response.isDynamicHit
    → взять static + dynamic из локального кэша (ноль байт с сервера)

response.isCacheHit
    → взять static из кэша, dynamic с сервера
    → cache.updateDynamic(...)

иначе (Full)
    → cache.update(все данные включая dynamic)
```

---

### Диаграмма принятия решений (обновлённая)

```
load(screenId, forceRefresh)
        │
        ├─ forceRefresh / isExpired → cache.invalidate()
        │
        fetch(cachedKey: storedKey, dynamicKey: storedDynKey)
                │
    ┌───────────┼──────────────────┐
    │           │                  │
isDynamicHit  isCacheHit      Full response
    │           │                  │
local cache  server dynamic   cache.update(
(0 bytes)   + local static    static, dynamic,
    │           │              cache_key, dyn_key)
    │       cache.updateDynamic     │
    │           │                  │
    └───────────┴──────────────────┘
                │
           return ScreenData
           { staticScreen, dynamic, cacheKey, dynamicKey }
```

---

### Тесты, добавленные в пункте 11

**SPM (`swift test`, 46 тестов всего):**

`BDUICacheTests` (+4):
- `test_storeDynamicKeyAndRetrieve` — dynamic_key сохраняется и читается
- `test_storeDynamicDataAndRetrieve` — dynamic данные сохраняются и читаются
- `test_updateDynamic_overwritesDynamicKeyAndData` — updateDynamic перезаписывает данные
- `test_invalidateRemovesDynamicData` — invalidate удаляет и dynamic поля

`BDUIResponseDecodingTests` (+1):
- `test_dynamicHitResponseDecoding` — DynamicHit декодируется корректно (нет `ui`, есть оба ключа)

`BDUIScreenLoaderTests` (+6):
- `test_firstLoad_sendsNoDynamicKey` — при первом запросе `dynamic_key` не отправляется
- `test_secondLoad_sendsDynamicKey` — после первой загрузки dynamic_key отправляется
- `test_cacheHit_updatesDynamicCache` — при CacheHit локальный кэш динамики обновляется
- `test_dynamicHit_returnsDataFromLocalCache` — DynamicHit возвращает данные без сети
- `test_dynamicHit_doesNotChangeCache` — DynamicHit не меняет кэш
- `test_dynamicHit_sendsCorrectKeys` — оба ключа отправляются на сервер
- `test_totalRequestCount_threeLoads` → обновлён (Full → CacheHit → DynamicHit)

`BDUIClientNetworkTests` (+1):
- `test_fetchWithDynamicKey_urlHasDynamicKeyQueryParam` — `dynamic_key` попадает в URL