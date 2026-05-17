# SOLID в кодовой базе сервера

## S — Single Responsibility Principle

> Каждый модуль отвечает за одну вещь и меняется только по одной причине.

```
Компонент               Единственная ответственность
─────────────────────   ────────────────────────────────────────────────
domain/protocol.rs      хранить константы версии
domain/screen.rs        определять контракт экрана
domain/models.rs        описывать формы ответов (DTO)
infrastructure/hashing  вычислять SHA-256 canonical hash
infrastructure/registry хранить и искать экраны по id
infrastructure/screen/* предоставлять данные одного конкретного экрана
application/service     принимать решение cache-hit/miss/first
server/handlers/screen  разбирать HTTP-запрос и вернуть HTTP-ответ
server/error.rs         конвертировать ошибки домена в HTTP-статусы
metrics/                считать и агрегировать статистику
```

Пример: когда изменится **формат JSON ответа** — меняем только `domain/models.rs`.
Когда изменится **логика кэша** — меняем только `application/screen_service.rs`.
Когда изменится **URL эндпоинта** — меняем только `server/mod.rs`.

---

## O — Open/Closed Principle

> Открыт для расширения, закрыт для модификации.

### Добавление экрана — только новый код

```
До:                           После:
register_all()                register_all()
  .register(ProfileScreen)      .register(ProfileScreen)
  .register(HomeScreen)    ─→   .register(HomeScreen)
                                .register(CartScreen)    ← новое
```

`ScreenService`, `AppState`, все хендлеры — **не трогаются**.

### Как это достигается — через трейт ScreenRepository

```
handlers/screen.rs
   │
   │ вызывает
   ▼
screen_service.handle(id, key)
   │
   │ вызывает
   ▼
repository.find(id)         ← &dyn ScreenRepository
   │
   │ конкретная реализация:
   ▼
ScreenRegistry::find(id)    ← HashMap lookup

Можно подменить на DatabaseRegistry, RemoteRegistry, CachingRegistry
без изменения ScreenService или хендлеров.
```

---

## L — Liskov Substitution Principle

> Любая реализация трейта `Screen` должна работать корректно там, где ожидается `dyn Screen`.

Все 5 экранов взаимозаменяемы:

```
dyn Screen
   │
   ├─ ProfileScreen   → id: "profile",  cache_key: "9e4a…"
   ├─ HomeScreen      → id: "home",     cache_key: "b2f1…"
   ├─ SettingsScreen  → id: "settings", cache_key: "c3d7…"
   ├─ CatalogScreen   → id: "catalog",  cache_key: "a1e5…"
   └─ ProductScreen   → id: "product",  cache_key: "f8c2…"
```

Инвариант: `screen.cache_key()` всегда стабилен в рамках одного запуска процесса (гарантируется `LazyLock`). Любой экран, нарушающий это — нарушает LSP.

---

## I — Interface Segregation Principle

> Клиент не должен зависеть от методов, которые не использует.

### ScreenRepository — только то, что нужно хендлеру

```
Хендлер использует:          Хендлер НЕ использует:
  repository.find(id)          registry.register()
  repository.all_ids()         registry.screens (поле)
                                внутренности HashMap
```

`ScreenRepository` трейт содержит ровно два метода — `find` и `all_ids`. Хендлер видит только интерфейс, не реализацию.

### Screen — только то, что нужно сервису

```rust
pub trait Screen: Send + Sync {
    fn id(&self) -> &'static str;
    fn cache_key(&self) -> &'static str;
    fn static_screen(&self) -> &'static StaticScreen;
    fn dynamic_data(&self) -> Value;
    fn full_response_size(&self) -> usize;
    // full_response() — default, редко переопределяется
}
```

`ScreenService` использует все пять методов. Если бы он использовал только три — трейт стоило бы разбить.

---

## D — Dependency Inversion Principle

> Модули верхнего уровня не зависят от конкретных реализаций нижнего.

### Граф зависимостей

```
                 main.rs
                    │
          ┌─────────┼─────────┐
          │                   │
    AppState              register_all()
      │                        │
      ▼                        ▼
ScreenService          ScreenRegistry
      │ depends on             │ implements
      ▼                        ▼
ScreenRepository (trait)   Screen (trait)
      △                        △
      │ implemented by         │ implemented by
      │                        │
ScreenRegistry            ProfileScreen
                          HomeScreen
                          …
```

```
handlers/screen.rs
         │ Arc<ScreenService>      ← знает тип ScreenService
         │
ScreenService
         │ Arc<dyn ScreenRepository>  ← НЕ знает ScreenRegistry
         │
ScreenRegistry                        ← конкретный тип
```

`ScreenService` создаётся с `Arc<dyn ScreenRepository>` — его можно тестировать с `MockRepository` без поднятия реального реестра экранов.

### Пример теста без реального реестра

```rust
struct MockRepository {
    screen: MockScreen,
}
impl ScreenRepository for MockRepository {
    fn find(&self, _id: &str) -> Option<&dyn Screen> { Some(&self.screen) }
    fn all_ids(&self) -> Vec<&'static str> { vec!["mock"] }
}

let service = ScreenService::new(Arc::new(MockRepository { … }));
let result  = service.handle("mock", None).unwrap();
// Тест ScreenService без LazyLock, без JSON файлов, без SHA-256
```
