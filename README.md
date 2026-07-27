# Endless Docs Client

Публичный desktop-first Flutter-клиент Endless Docs.

Текущая цель репозитория — выпустить самостоятельный `Client MVP`, который
работает без сети, регистрации и облачного аккаунта. Структурированные локальные
данные хранятся в Isar, но базой владеет только `locald`. Flutter UI, MCP server
и CLI работают через один versioned Local API.

## Текущее состояние

Реализован проверяемый Windows-first vertical slice:

- Flutter UI создаёт local workspaces и document tree, редактирует текст,
  перемещает документы, восстанавливает их из корзины и показывает состояния
  autosave/retry/conflict;
- пространства переименовываются, архивируются в read-only режиме,
  восстанавливаются и удаляются каскадно; запрос выхода flush-ит pending edit;
- локальный поиск по заголовкам и содержимому обновляется атомарно с документами,
  сохраняется после cold restart и может быть перестроен без сети;
- отдельный pure Dart process `locald` — единственный владелец Isar;
- UI и CLI подключаются через authenticated Local API на `127.0.0.1`;
- domain mutation, command outcome, Operation Log и event sequence фиксируются
  одной durable Isar transaction;
- собранный Windows bundle включает `locald.exe` и `isar.dll`, поэтому runtime не
  скачивает компоненты и не требует внешнего сервера;
- cold restart, search rebuild, duplicate `command_id`, unauthorized request,
  architecture boundaries и Flutter states покрыты автоматическими тестами.

Полная матрица реализованного и ещё необходимого находится в
[implementation status](docs/architecture/implementation-status.md).

## Разработка и проверка

Требуются Flutter 3.38+/Dart 3.10+ и Windows C++ build tools.

```powershell
dart pub get
.\tool\verify.ps1
.\tool\build_windows.ps1
.\tool\smoke_windows.ps1
```

Release bundle создаётся в `dist/endless-windows-x64`. Запуск
`endless_app.exe` автоматически обнаруживает или поднимает bundled `locald`.
Для изолированного development/smoke profile можно задать
`ENDLESS_PROFILE_ROOT` абсолютным путём внутри рабочего окружения.

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
- [implementation status](docs/architecture/implementation-status.md).

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
