# Server Documentation

| Файл | О чём |
|---|---|
| [01-overview.md](01-overview.md) | Общая архитектура, слои, файловая структура, паттерны |
| [02-bdui-protocol.md](02-bdui-protocol.md) | Протокол умного кэширования: запросы, ответы, cache_key |
| [03-layers.md](03-layers.md) | Детальный разбор каждого слоя с кодом |
| [04-request-lifecycle.md](04-request-lifecycle.md) | Жизненный цикл запроса от TCP до байт ответа |
| [05-extensibility.md](05-extensibility.md) | Как добавить экран, версию, эндпоинт |
| [06-solid.md](06-solid.md) | SOLID принципы — где и как применены |

## Быстрый старт

```bash
cargo run
# BDUI server (protocol v1) → http://localhost:3000

# первый запрос
curl http://localhost:3000/bdui/screen/profile | jq .

# повторный запрос с cache_key
curl "http://localhost:3000/bdui/screen/profile?cache_key=<key из предыдущего ответа>" | jq .

# метаданные протокола
curl http://localhost:3000/bdui/meta | jq .

# метрики
curl http://localhost:3000/metrics | jq .
```
