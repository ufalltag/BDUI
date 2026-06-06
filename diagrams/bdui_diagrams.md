# Диаграммы работы BDUI

Исходники в формате [Mermaid](https://mermaid.live). Чтобы получить картинку: открой
https://mermaid.live, вставь нужный блок — справа экспорт в PNG/SVG для Word.
На GitHub эти блоки рендерятся автоматически.

---

## 1. Суть BDUI: кто описывает интерфейс

Классический подход против Backend-Driven UI. В обычном приложении вёрстка «зашита»
в клиент, и любое изменение требует релиза в App Store. В BDUI описание экрана
живёт на сервере, а клиент — это универсальный «движок отрисовки».

```mermaid
flowchart LR
    subgraph classic["Классическое приложение"]
        direction TB
        c_be["Сервер<br/>(только данные)"] -->|JSON данные| c_app["Приложение<br/>(вёрстка внутри кода)"]
        c_app --> c_ui["UI"]
        c_note["Изменить экран =<br/>новый релиз в App Store"]
    end

    subgraph bdui["Backend-Driven UI"]
        direction TB
        b_be["Сервер<br/>(описание UI + данные)"] -->|JSON: что и как рисовать| b_app["Приложение<br/>(движок-рендерер)"]
        b_app --> b_ui["UI"]
        b_note["Изменить экран =<br/>правка JSON на сервере,<br/>без релиза"]
    end

    classic ~~~ bdui
```

---

## 2. Из чего состоит BDUI-ответ

Описание экрана делится на неизменную разметку (`static`) и обновляемые данные
(`dynamic`). К ним добавляются два хэша-идентификатора версий.

```mermaid
flowchart TD
    resp["BDUI-ответ сервера"]
    resp --> ui["ui"]
    resp --> ck["cache_key<br/>SHA-256 от static<br/>(версия разметки)"]
    resp --> dk["dynamic_key<br/>SHA-256 от dynamic<br/>(версия данных)"]
    resp --> pv["protocol_version"]

    ui --> st["static<br/>разметка, иерархия<br/>компонентов, конфигурация<br/>(меняется редко)"]
    ui --> dy["dynamic<br/>тексты, списки, числа<br/>(меняется часто)"]

    st -. хэшируется .-> ck
    dy -. хэшируется .-> dk

    classDef k fill:#eef,stroke:#557;
    classDef s fill:#efe,stroke:#575;
    classDef d fill:#fee,stroke:#755;
    class ck,dk k
    class st s
    class dy d
```

---

## 3. Главный флоу: что видит пользователь при открытии экрана

Трёхуровневое кэширование. Чем больше совпало ключей — тем меньше данных по сети.
Это основная диаграмма «как работает приложение».

```mermaid
sequenceDiagram
    actor U as Пользователь
    participant A as iOS-приложение
    participant C as Локальный кэш
    participant S as Сервер (Rust)

    Note over U,S: 1-е открытие экрана — кэша ещё нет
    U->>A: открывает экран profile
    A->>C: есть cache_key / dynamic_key?
    C-->>A: нет
    A->>S: GET /bdui/screen/profile
    S-->>A: ПОЛНЫЙ ответ: static + dynamic + ключи (~5 КБ)
    A->>C: сохранить static, dynamic, оба ключа
    A-->>U: экран отрисован

    Note over U,S: Повторное открытие — разметка не менялась
    U->>A: снова открывает profile
    A->>C: берём сохранённые ключи
    A->>S: GET ...?cache_key=..&dynamic_key=..
    alt Данные изменились (CacheHit)
        S-->>A: только dynamic + новый dynamic_key (~500 Б)
        A->>C: обновить только динамику
        A-->>U: разметка из кэша + свежие данные
    else Ничего не изменилось (DynamicHit)
        S-->>A: только ключи, без "ui" (~100 Б)
        A->>C: данные взять из кэша
        A-->>U: экран целиком из кэша, 0 данных по сети
    end
```

---

## 4. Решение сервера: какой ответ вернуть

Серверный алгоритм выбора одного из четырёх уровней.

```mermaid
flowchart TD
    start(["Запрос экрана<br/>cache_key?, dynamic_key?"]) --> ck{"cache_key<br/>совпал с текущим?"}
    ck -->|"нет / не передан"| full["ПОЛНЫЙ ОТВЕТ<br/>static + dynamic + ключи"]
    full --> first{"клиент передавал<br/>cache_key?"}
    first -->|нет| L0["First"]
    first -->|да| L1["CacheMiss<br/>(разметка обновилась)"]

    ck -->|да| dk{"dynamic_key<br/>совпал с текущим?"}
    dk -->|нет| hit["CacheHit<br/>только dynamic + dynamic_key<br/>≈ 500 Б"]
    dk -->|да| dyn["DynamicHit<br/>только ключи, без ui<br/>≈ 100 Б"]

    classDef big fill:#fde,stroke:#a37;
    classDef mid fill:#fec,stroke:#a73;
    classDef sml fill:#dfe,stroke:#3a7;
    class L0,L1 big
    class hit mid
    class dyn sml
```

---

## 5. Решение клиента: откуда брать данные

Клиентский загрузчик `BDUIScreenLoader` обрабатывает три ветки ответа.

```mermaid
flowchart TD
    start(["load(screenId)"]) --> inval{"forceRefresh<br/>или истёк TTL?"}
    inval -->|да| clr["Очистить кэш экрана"]
    inval -->|нет| keys
    clr --> keys["Прочитать cache_key,<br/>dynamic_key из кэша"]
    keys --> fetch["Запрос на сервер<br/>с известными ключами"]
    fetch --> type{"тип ответа"}

    type -->|DynamicHit| d1["static + dynamic<br/>из локального кэша<br/>(0 байт данных по сети)"]
    type -->|CacheHit| d2["static из кэша,<br/>dynamic из ответа,<br/>обновить кэш динамики"]
    type -->|Full| d3["сохранить всё в кэш<br/>(static, dynamic, ключи)"]

    d1 --> render["Отрисовать экран"]
    d2 --> render
    d3 --> render

    classDef sml fill:#dfe,stroke:#3a7;
    classDef mid fill:#fec,stroke:#a73;
    classDef big fill:#fde,stroke:#a37;
    class d1 sml
    class d2 mid
    class d3 big
```

---

## 6. Рендеринг в две фазы

Почему обновление дешёвое: разметка строится один раз, дальше меняется только контент.

```mermaid
flowchart LR
    subgraph p1["Фаза 1 — Построение (buildLayout)"]
        direction TB
        s1["static-описание"] --> f1["Фабрика компонентов"]
        f1 --> v1["Иерархия UIView<br/>(заголовки, кнопки,<br/>сетки, секции...)"]
    end
    subgraph p2["Фаза 2 — Обновление (applyDynamic)"]
        direction TB
        d2["dynamic-данные"] --> u2["Передать значения<br/>в готовые view по id"]
    end

    v1 -->|строится 1 раз<br/>на версию разметки| p2
    u2 -->|на каждый ответ<br/>CacheHit / DynamicHit| screen["Экран обновлён<br/>без пересборки вёрстки"]
```
