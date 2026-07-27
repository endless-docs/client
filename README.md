# Endless Docs Client

Публичный desktop-first Flutter-клиент Endless Docs.

Текущая цель репозитория — выпустить самостоятельный `Client MVP`, который
работает без сети, регистрации и облачного аккаунта. Структурированные локальные
данные хранятся в Isar, но базой владеет только `locald`. Flutter UI, MCP server
и CLI работают через один versioned Local API.

## Архитектура

Клиентская архитектура находится в
[docs/architecture](docs/architecture/README.md):

- [overview](docs/architecture/overview.md);
- [process topology](docs/architecture/process-topology.md);
- [module boundaries](docs/architecture/module-boundaries.md);
- [Local API](docs/architecture/local-api.md);
- [persistence](docs/architecture/persistence.md);
- [domain model](docs/architecture/domain-model.md);
- [data flow](docs/architecture/data-flow.md);
- [MCP and CLI](docs/architecture/mcp-and-cli.md);
- [security](docs/architecture/security.md);
- [quality and testing](docs/architecture/quality-and-testing.md);
- [delivery plan](docs/architecture/delivery-plan.md);
- [traceability](docs/architecture/traceability.md);
- [open decisions](docs/architecture/open-decisions.md).

## Неподвижные ограничения

- Flutter/Dart — основной client stack.
- `locald` — единственный process owner Isar и локального состояния.
- UI, MCP и CLI не открывают Isar и не импортируют persistence adapter.
- Подтверждение сохранения выдаётся только после durable local commit.
- Operation Log создаётся атомарно с domain mutation.
- Файл Isar не является публичным, backup или sync format.
- Машиночитаемые cross-repository contracts принадлежат `endless-docs/contracts`.
- Cloud capabilities не входят в текущий Client MVP.

## Нормативный источник

Общесистемные решения находятся в `endless-docs/architecture`. Этот репозиторий
содержит только клиентские implementation details и доказательства их выполнения.
