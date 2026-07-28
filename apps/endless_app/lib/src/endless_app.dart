import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:codex_app_server/codex_app_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_api/local_api.dart';

import 'app_controller.dart';
import 'endless_theme.dart';

final class EndlessApp extends StatelessWidget {
  const EndlessApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Endless Docs',
    debugShowCheckedModeBanner: false,
    theme: EndlessTheme.light(),
    darkTheme: EndlessTheme.dark(),
    themeMode: ThemeMode.system,
    themeAnimationDuration: const Duration(milliseconds: 260),
    themeAnimationCurve: const Cubic(0.2, 0.8, 0.2, 1),
    home: _Home(controller: controller),
  );
}

final class _Home extends StatefulWidget {
  const _Home({required this.controller});

  final AppController controller;

  @override
  State<_Home> createState() => _HomeState();
}

final class _HomeState extends State<_Home> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _flushBeforeExit);
  }

  Future<AppExitResponse> _flushBeforeExit() async {
    try {
      await widget.controller.flushPendingChanges();
      return AppExitResponse.exit;
    } on Object {
      return AppExitResponse.cancel;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (BuildContext context, Widget? child) =>
        switch (widget.controller.phase) {
          AppPhase.starting => const _StartingView(),
          AppPhase.failed => _FailureView(
            message: widget.controller.errorMessage ?? 'Неизвестная ошибка',
            onRetry: widget.controller.initialize,
          ),
          AppPhase.ready => _ReadyView(controller: widget.controller),
        },
  );
}

final class _StartingView extends StatelessWidget {
  const _StartingView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        label: 'Запуск локального хранилища',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _BrandLogo(width: 230),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Запускаем локальное хранилище…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Знания под вашим контролем.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _BrandLogo(width: 210),
                const SizedBox(height: 32),
                Icon(
                  Icons.storage_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Локальное хранилище недоступно',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const _BrandLogo(width: 222, forceDarkBackgroundVariant: true),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: _LocalStatusBadge(reconnecting: controller.reconnecting),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          SizedBox(width: 312, child: _NavigationPane(controller: controller)),
          const VerticalDivider(width: 1),
          Expanded(
            child: ColoredBox(
              color: colors.surface,
              child: _ContentPane(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

final class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.width,
    this.forceDarkBackgroundVariant = false,
  });

  final double width;
  final bool forceDarkBackgroundVariant;

  @override
  Widget build(BuildContext context) {
    final bool dark =
        forceDarkBackgroundVariant ||
        Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      image: true,
      label: 'Endless Docs',
      child: SvgPicture.asset(
        dark
            ? 'assets/brand/endless-docs-logo-horizontal-dark.svg'
            : 'assets/brand/endless-docs-logo-horizontal-light.svg',
        key: ValueKey<String>(
          dark ? 'brand-logo-dark-svg' : 'brand-logo-light-svg',
        ),
        width: width,
        fit: BoxFit.contain,
      ),
    );
  }
}

final class _LocalStatusBadge extends StatelessWidget {
  const _LocalStatusBadge({required this.reconnecting});

  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String label = reconnecting
        ? 'ПЕРЕПОДКЛЮЧЕНИЕ…'
        : 'ЛОКАЛЬНО  /  СОХРАНЕНО';
    return Semantics(
      label: reconnecting
          ? 'Переподключение к локальному хранилищу'
          : 'Данные сохранены локально',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (reconnecting)
                SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else
                Icon(Icons.circle, size: 10, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: colors.primary,
                  fontFamily: 'IBM Plex Mono',
                  fontFamilyFallback: const <String>['Consolas', 'Courier New'],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ContentPane extends StatelessWidget {
  const _ContentPane({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.showRecycleBin) {
      return _RecycleBinView(controller: controller);
    }
    if (controller.selectedDocument == null) {
      return _EmptyDocumentView(controller: controller);
    }
    final bool readOnly = !controller.isSelectedWorkspaceWritable;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (controller.aiPanelOpen && constraints.maxWidth < 760) {
          return _AiPanel(controller: controller, readOnly: readOnly);
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: DocumentEditor(
                key: ValueKey<String>(controller.selectedDocumentId!),
                controller: controller,
                document: controller.selectedDocument!,
                readOnly: readOnly,
              ),
            ),
            if (controller.aiPanelOpen) ...<Widget>[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 380,
                child: _AiPanel(controller: controller, readOnly: readOnly),
              ),
            ],
          ],
        );
      },
    );
  }
}

final class _NavigationPane extends StatelessWidget {
  const _NavigationPane({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 2),
          child: _SectionLabel('РАБОЧЕЕ ПРОСТРАНСТВО'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: controller.workspaces.isEmpty
                    ? const Text('Нет пространства')
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: controller.selectedWorkspaceId,
                          isExpanded: true,
                          items: controller.workspaces
                              .map(
                                (JsonMap workspace) => DropdownMenuItem<String>(
                                  value: requireString(
                                    workspace,
                                    'workspace_id',
                                  ),
                                  child: Text(
                                    '${requireString(workspace, 'name')}'
                                    '${workspace['lifecycle'] == 'archived' ? ' (архив)' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              _runUiAction(
                                context,
                                () => controller.selectWorkspace(value),
                              );
                            }
                          },
                        ),
                      ),
              ),
              PopupMenuButton<_WorkspaceAction>(
                tooltip: 'Действия с пространством',
                enabled: controller.selectedWorkspace != null,
                onSelected: (_WorkspaceAction action) {
                  switch (action) {
                    case _WorkspaceAction.rename:
                      unawaited(_renameWorkspace(context, controller));
                    case _WorkspaceAction.archive:
                      unawaited(
                        _setWorkspaceArchived(context, controller, true),
                      );
                    case _WorkspaceAction.restore:
                      _runUiAction(
                        context,
                        () => controller.setSelectedWorkspaceArchived(false),
                      );
                    case _WorkspaceAction.delete:
                      unawaited(_deleteWorkspace(context, controller));
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_WorkspaceAction>>[
                      const PopupMenuItem<_WorkspaceAction>(
                        value: _WorkspaceAction.rename,
                        child: Text('Переименовать'),
                      ),
                      if (controller.isSelectedWorkspaceWritable)
                        const PopupMenuItem<_WorkspaceAction>(
                          value: _WorkspaceAction.archive,
                          child: Text('Архивировать'),
                        )
                      else
                        const PopupMenuItem<_WorkspaceAction>(
                          value: _WorkspaceAction.restore,
                          child: Text('Вернуть из архива'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<_WorkspaceAction>(
                        value: _WorkspaceAction.delete,
                        child: Text('Удалить пространство'),
                      ),
                    ],
              ),
              IconButton(
                tooltip: 'Новое пространство',
                onPressed: () => _createWorkspace(context, controller),
                icon: const Icon(Icons.add_box_outlined),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: _SearchBox(
            controller: controller,
            enabled:
                controller.selectedWorkspaceId != null &&
                !controller.showRecycleBin,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SectionLabel(
                  controller.showRecycleBin ? 'Корзина' : 'Документы',
                ),
              ),
              IconButton(
                tooltip: controller.showRecycleBin
                    ? 'Вернуться к документам'
                    : 'Открыть корзину',
                onPressed: controller.selectedWorkspaceId == null
                    ? null
                    : () => _runUiAction(
                        context,
                        () => controller.setRecycleBin(
                          !controller.showRecycleBin,
                        ),
                      ),
                icon: Icon(
                  controller.showRecycleBin
                      ? Icons.arrow_back
                      : Icons.delete_outline,
                ),
              ),
              IconButton(
                tooltip: 'Новый документ',
                onPressed:
                    controller.selectedWorkspaceId == null ||
                        controller.showRecycleBin ||
                        !controller.isSelectedWorkspaceWritable
                    ? null
                    : () => _createDocument(context, controller),
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.showRecycleBin
              ? _RecycleList(controller: controller)
              : controller.hasSearch
              ? _SearchResults(controller: controller)
              : controller.activeDocuments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      controller.isSelectedWorkspaceWritable
                          ? 'Создайте первый документ — интернет не требуется.'
                          : 'Архивное пространство доступно только для чтения.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: controller.documentTree.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DocumentTreeEntry entry =
                        controller.documentTree[index];
                    final JsonMap document = entry.document;
                    final String id = requireString(document, 'document_id');
                    return ListTile(
                      contentPadding: EdgeInsets.only(
                        left: 12 + entry.depth * 20,
                        right: 4,
                      ),
                      selected: id == controller.selectedDocumentId,
                      leading: Icon(
                        controller.activeDocuments.any(
                              (JsonMap candidate) =>
                                  candidate['parent_id'] == id,
                            )
                            ? Icons.folder_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(
                        requireString(document, 'title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: controller.isSelectedWorkspaceWritable
                          ? PopupMenuButton<String>(
                              tooltip: 'Действия с документом',
                              onSelected: (String action) {
                                if (action == 'child') {
                                  unawaited(
                                    _createDocument(
                                      context,
                                      controller,
                                      parentId: id,
                                    ),
                                  );
                                } else if (action == 'move') {
                                  unawaited(
                                    _moveDocument(
                                      context,
                                      controller,
                                      document,
                                    ),
                                  );
                                } else if (action == 'delete') {
                                  unawaited(
                                    _deleteDocument(context, controller, id),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'child',
                                      child: Text('Создать вложенный'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'move',
                                      child: Text('Переместить'),
                                    ),
                                    PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                            )
                          : null,
                      onTap: () => _runUiAction(
                        context,
                        () => controller.selectDocument(id),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFamily: 'IBM Plex Mono',
      fontFamilyFallback: const <String>['Consolas', 'Courier New'],
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.9,
    ),
  );
}

final class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.controller, required this.enabled});

  final AppController controller;
  final bool enabled;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

final class _SearchBoxState extends State<_SearchBox> {
  late final TextEditingController _text;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.searchQuery);
  }

  @override
  void didUpdateWidget(_SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.controller.searchQuery) {
      _text.value = TextEditingValue(
        text: widget.controller.searchQuery,
        selection: TextSelection.collapsed(
          offset: widget.controller.searchQuery.length,
        ),
      );
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(widget.controller.search(value)),
    );
  }

  void _submit(String value) {
    _debounce?.cancel();
    unawaited(widget.controller.search(value));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    enabled: widget.enabled,
    onChanged: _changed,
    onSubmitted: _submit,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Поиск без интернета',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: widget.controller.searching
          ? const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.controller.hasSearch
          ? IconButton(
              tooltip: 'Очистить поиск',
              onPressed: () {
                _text.clear();
                _submit('');
              },
              icon: const Icon(Icons.close),
            )
          : null,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}

final class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final String? error = controller.searchError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (controller.searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Ничего не найдено локально.'),
        ),
      );
    }
    return ListView.builder(
      itemCount: controller.searchResults.length,
      itemBuilder: (BuildContext context, int index) {
        final JsonMap hit = controller.searchResults[index];
        final String id = requireString(hit, 'document_id');
        final String snippet = requireString(hit, 'snippet');
        return ListTile(
          selected: id == controller.selectedDocumentId,
          leading: const Icon(Icons.manage_search),
          title: Text(
            requireString(hit, 'title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: snippet.isEmpty
              ? null
              : Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () =>
              _runUiAction(context, () => controller.selectDocument(id)),
        );
      },
    );
  }
}

final class _RecycleList extends StatelessWidget {
  const _RecycleList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.deletedDocuments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Корзина пуста.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: controller.deletedDocuments.length,
      itemBuilder: (BuildContext context, int index) {
        final JsonMap document = controller.deletedDocuments[index];
        final String id = requireString(document, 'document_id');
        return ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(
            requireString(document, 'title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: 'Восстановить документ',
            onPressed: controller.isSelectedWorkspaceWritable
                ? () => _runUiAction(
                    context,
                    () => controller.restoreDocument(id),
                  )
                : null,
            icon: const Icon(Icons.restore),
          ),
        );
      },
    );
  }
}

final class _RecycleBinView extends StatelessWidget {
  const _RecycleBinView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _BrandStateIcon(icon: Icons.delete_sweep_outlined),
              const SizedBox(height: 24),
              Text(
                controller.deletedDocuments.isEmpty
                    ? 'Корзина пуста'
                    : 'Выберите документ слева для восстановления',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Удалённые документы остаются на устройстве, пока вы '
                'не восстановите их.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _runUiAction(
                  context,
                  () => controller.setRecycleBin(false),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('К документам'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _EmptyDocumentView extends StatelessWidget {
  const _EmptyDocumentView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool noWorkspace = controller.selectedWorkspaceId == null;
    final bool archived =
        !noWorkspace && !controller.isSelectedWorkspaceWritable;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _BrandStateIcon(icon: Icons.edit_note_rounded),
                const SizedBox(height: 24),
                Text(
                  noWorkspace
                      ? 'Создайте локальное пространство'
                      : archived
                      ? 'Пространство находится в архиве'
                      : 'Выберите или создайте документ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  noWorkspace
                      ? 'Документы останутся доступными на этом устройстве — '
                            'интернет не требуется.'
                      : archived
                      ? 'Верните пространство из архива, чтобы снова '
                            'редактировать документы.'
                      : 'Знания под вашим контролем — начните с нового '
                            'локального документа.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: noWorkspace
                      ? () => _createWorkspace(context, controller)
                      : archived
                      ? () => _runUiAction(
                          context,
                          () => controller.setSelectedWorkspaceArchived(false),
                        )
                      : () => _createDocument(context, controller),
                  child: Text(
                    noWorkspace
                        ? 'Создать пространство'
                        : archived
                        ? 'Вернуть из архива'
                        : 'Создать документ',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _BrandStateIcon extends StatelessWidget {
  const _BrandStateIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(EndlessBrand.marketingRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Icon(icon, size: 36, color: colors.primary),
      ),
    );
  }
}

enum _SaveState { saved, pending, saving, failed, conflict }

enum _EditorMode { source, preview }

enum _WorkspaceAction { rename, archive, restore, delete }

final class DocumentEditor extends StatefulWidget {
  const DocumentEditor({
    required this.controller,
    required this.document,
    required this.readOnly,
    super.key,
  });

  final AppController controller;
  final JsonMap document;
  final bool readOnly;

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

final class _DocumentEditorState extends State<DocumentEditor> {
  late TextEditingController _title;
  late TextEditingController _content;
  final FocusNode _contentFocus = FocusNode();
  final List<TextEditingValue> _undoStack = <TextEditingValue>[];
  final List<TextEditingValue> _redoStack = <TextEditingValue>[];
  late TextEditingValue _lastContentValue;
  late int _revision;
  String? _blockId;
  Timer? _autosave;
  Timer? _historyGroupTimer;
  Future<void>? _activeSave;
  bool _applyingContentValue = false;
  bool _historyGroupOpen = false;
  bool _dirty = false;
  _SaveState _state = _SaveState.saved;
  _EditorMode _mode = _EditorMode.source;

  @override
  void initState() {
    super.initState();
    _readDocument(widget.document);
    _content.addListener(_contentValueChanged);
    widget.controller.attachEditor(this, _flushBeforeNavigation);
  }

  @override
  void didUpdateWidget(DocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int incomingRevision = requireInt(widget.document, 'revision');
    if (incomingRevision != _revision &&
        (!_dirty || _state == _SaveState.conflict)) {
      final List<JsonMap> blocks = requireMapList(widget.document, 'blocks');
      _revision = incomingRevision;
      _blockId = blocks.isEmpty ? null : blocks.first['block_id'] as String?;
      _title.text = requireString(widget.document, 'title');
      _replaceContentFromExternal(
        blocks.isEmpty
            ? ''
            : (requireMap(blocks.first, 'payload')['text'] as String?) ?? '',
      );
      _dirty = false;
      _state = _SaveState.saved;
    }
  }

  void _readDocument(JsonMap document) {
    _revision = requireInt(document, 'revision');
    final List<JsonMap> blocks = requireMapList(document, 'blocks');
    _blockId = blocks.isEmpty ? null : blocks.first['block_id'] as String?;
    final String text = blocks.isEmpty
        ? ''
        : (requireMap(blocks.first, 'payload')['text'] as String?) ?? '';
    _title = TextEditingController(text: requireString(document, 'title'));
    _content = TextEditingController(text: text);
    _lastContentValue = _content.value;
  }

  void _contentValueChanged() {
    final TextEditingValue value = _content.value;
    if (_applyingContentValue) {
      _lastContentValue = value;
      return;
    }
    if (value.text != _lastContentValue.text) {
      if (!_historyGroupOpen) {
        _undoStack.add(_lastContentValue);
        if (_undoStack.length > 100) {
          _undoStack.removeAt(0);
        }
      }
      _redoStack.clear();
      _historyGroupOpen = true;
      _historyGroupTimer?.cancel();
      _historyGroupTimer = Timer(
        const Duration(milliseconds: 650),
        _finishHistoryGroup,
      );
    }
    _lastContentValue = value;
  }

  void _finishHistoryGroup() {
    _historyGroupTimer?.cancel();
    _historyGroupTimer = null;
    _historyGroupOpen = false;
  }

  void _replaceContentFromExternal(String text) {
    _finishHistoryGroup();
    _applyingContentValue = true;
    _content.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _applyingContentValue = false;
    _lastContentValue = _content.value;
    _undoStack.clear();
    _redoStack.clear();
  }

  void _undo() {
    if (widget.readOnly || _undoStack.isEmpty) {
      return;
    }
    _finishHistoryGroup();
    final TextEditingValue current = _content.value;
    final TextEditingValue previous = _undoStack.removeLast();
    _redoStack.add(current);
    _applyHistoryValue(previous);
  }

  void _redo() {
    if (widget.readOnly || _redoStack.isEmpty) {
      return;
    }
    _finishHistoryGroup();
    final TextEditingValue current = _content.value;
    final TextEditingValue next = _redoStack.removeLast();
    _undoStack.add(current);
    _applyHistoryValue(next);
  }

  void _applyHistoryValue(TextEditingValue value) {
    _applyingContentValue = true;
    _content.value = value;
    _applyingContentValue = false;
    _lastContentValue = value;
    _changed(value.text);
    _contentFocus.requestFocus();
  }

  TextSelection get _safeSelection {
    final TextSelection selection = _content.selection;
    if (!selection.isValid ||
        selection.start > _content.text.length ||
        selection.end > _content.text.length) {
      return TextSelection.collapsed(offset: _content.text.length);
    }
    return selection;
  }

  void _wrapSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    if (widget.readOnly) {
      return;
    }
    _finishHistoryGroup();
    final String text = _content.text;
    final TextSelection selection = _safeSelection;
    final int start = selection.start;
    final int end = selection.end;
    final String selected = text.substring(start, end);
    final String body = selected.isEmpty ? placeholder : selected;
    final String replacement = '$prefix$body$suffix';
    final int selectionStart = start + prefix.length;
    final TextSelection nextSelection = selected.isEmpty
        ? TextSelection(
            baseOffset: selectionStart,
            extentOffset: selectionStart + body.length,
          )
        : TextSelection.collapsed(offset: start + replacement.length);
    _applyUserEdit(
      TextEditingValue(
        text: text.replaceRange(start, end, replacement),
        selection: nextSelection,
      ),
    );
  }

  void _insertText(String insertion) {
    if (widget.readOnly) {
      return;
    }
    _finishHistoryGroup();
    final String text = _content.text;
    final TextSelection selection = _safeSelection;
    _applyUserEdit(
      TextEditingValue(
        text: text.replaceRange(selection.start, selection.end, insertion),
        selection: TextSelection.collapsed(
          offset: selection.start + insertion.length,
        ),
      ),
    );
  }

  void _transformSelectedLines(String Function(String line, int index) change) {
    if (widget.readOnly) {
      return;
    }
    _finishHistoryGroup();
    final String text = _content.text;
    final TextSelection selection = _safeSelection;
    final int lineStart = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final int nextBreak = text.indexOf('\n', selection.end);
    final int lineEnd = nextBreak < 0 ? text.length : nextBreak;
    final String replacement = text
        .substring(lineStart, lineEnd)
        .split('\n')
        .indexed
        .map(((int, String) entry) => change(entry.$2, entry.$1))
        .join('\n');
    _applyUserEdit(
      TextEditingValue(
        text: text.replaceRange(lineStart, lineEnd, replacement),
        selection: TextSelection(
          baseOffset: lineStart,
          extentOffset: lineStart + replacement.length,
        ),
      ),
    );
  }

  void _setHeading(int level) {
    _transformSelectedLines((String line, int _) {
      final String body = line.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      final String marker = List<String>.filled(level, '#').join();
      return level == 0 ? body : '$marker $body';
    });
  }

  void _toggleLinePrefix(String prefix) {
    final TextSelection selection = _safeSelection;
    final String text = _content.text;
    final int lineStart = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final int nextBreak = text.indexOf('\n', selection.end);
    final int lineEnd = nextBreak < 0 ? text.length : nextBreak;
    final List<String> lines = text.substring(lineStart, lineEnd).split('\n');
    final bool remove = lines
        .where((String line) => line.isNotEmpty)
        .every((String line) => line.startsWith(prefix));
    _transformSelectedLines(
      (String line, int _) => line.isEmpty
          ? line
          : remove
          ? line.substring(prefix.length)
          : '$prefix$line',
    );
  }

  void _toggleNumberedList() {
    final RegExp marker = RegExp(r'^\d+\.\s+');
    final TextSelection selection = _safeSelection;
    final String text = _content.text;
    final int lineStart = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final int nextBreak = text.indexOf('\n', selection.end);
    final int lineEnd = nextBreak < 0 ? text.length : nextBreak;
    final List<String> lines = text.substring(lineStart, lineEnd).split('\n');
    final bool remove = lines
        .where((String line) => line.isNotEmpty)
        .every(marker.hasMatch);
    _transformSelectedLines((String line, int index) {
      if (line.isEmpty) {
        return line;
      }
      return remove
          ? line.replaceFirst(marker, '')
          : '${index + 1}. ${line.replaceFirst(marker, '')}';
    });
  }

  void _applyUserEdit(TextEditingValue value) {
    _content.value = value;
    _finishHistoryGroup();
    _changed(value.text);
    _contentFocus.requestFocus();
  }

  void _changed(String _) {
    _dirty = true;
    _autosave?.cancel();
    setState(() => _state = _SaveState.pending);
    _autosave = Timer(const Duration(milliseconds: 700), () {
      unawaited(_save());
    });
  }

  Future<void> _save({bool propagateError = false}) async {
    final Future<void>? active = _activeSave;
    if (active != null) {
      await active;
      if (_dirty) {
        await _save(propagateError: propagateError);
      }
      return;
    }
    if (!_dirty) {
      return;
    }
    final Future<void> save = _performSave(propagateError: propagateError);
    _activeSave = save;
    try {
      await save;
    } finally {
      _activeSave = null;
    }
  }

  Future<void> _performSave({required bool propagateError}) async {
    _autosave?.cancel();
    final String title = _title.text;
    final String content = _content.text;
    if (mounted) {
      setState(() => _state = _SaveState.saving);
    }
    try {
      final JsonMap saved = await widget.controller.saveDocument(
        documentId: requireString(widget.document, 'document_id'),
        title: title,
        text: content,
        expectedRevision: _revision,
        blockId: _blockId,
      );
      if (!mounted) {
        return;
      }
      _revision = requireInt(saved, 'revision');
      final List<JsonMap> blocks = requireMapList(saved, 'blocks');
      _blockId = blocks.isEmpty ? null : blocks.first['block_id'] as String?;
      final bool unchanged = _title.text == title && _content.text == content;
      _dirty = !unchanged;
      setState(
        () => _state = unchanged ? _SaveState.saved : _SaveState.pending,
      );
      if (!unchanged) {
        _autosave = Timer(const Duration(milliseconds: 700), () {
          unawaited(_save());
        });
      }
    } on LocalApiException catch (error) {
      if (!mounted) {
        if (propagateError) {
          rethrow;
        }
        return;
      }
      setState(
        () => _state = error.code == 'RevisionConflict'
            ? _SaveState.conflict
            : _SaveState.failed,
      );
      if (propagateError) {
        rethrow;
      }
    } on Object {
      if (mounted) {
        setState(() => _state = _SaveState.failed);
      }
      if (propagateError) {
        rethrow;
      }
    }
  }

  Future<void> _flushBeforeNavigation() async {
    _autosave?.cancel();
    while (_dirty) {
      await _save(propagateError: true);
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _historyGroupTimer?.cancel();
    widget.controller.detachEditor(this);
    _content.removeListener(_contentValueChanged);
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 28, 40, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionLabel('ЛОКАЛЬНЫЙ ДОКУМЕНТ'),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _title,
                readOnly: widget.readOnly,
                onChanged: widget.readOnly ? null : _changed,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: const InputDecoration(
                  hintText: 'Название',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.readOnly)
              const Chip(
                avatar: Icon(Icons.archive_outlined, size: 18),
                label: Text('Только чтение'),
              )
            else
              _SaveIndicator(state: _state, onSave: _save),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'AI-помощник',
              onPressed: () => widget.controller.setAiPanelOpen(
                !widget.controller.aiPanelOpen,
              ),
              icon: Icon(
                widget.controller.aiPanelOpen
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
              ),
            ),
            if (!widget.readOnly)
              IconButton(
                tooltip: 'Удалить документ',
                onPressed: () => _deleteDocument(
                  context,
                  widget.controller,
                  requireString(widget.document, 'document_id'),
                ),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_state == _SaveState.conflict)
          MaterialBanner(
            content: const Text(
              'Документ изменился. Перезагрузите его перед продолжением.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: widget.controller.reloadSelectedDocument,
                child: const Text('Перезагрузить'),
              ),
            ],
          ),
        Row(
          children: <Widget>[
            SegmentedButton<_EditorMode>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<_EditorMode>>[
                ButtonSegment<_EditorMode>(
                  value: _EditorMode.source,
                  icon: Icon(Icons.code),
                  label: Text('Исходник'),
                ),
                ButtonSegment<_EditorMode>(
                  value: _EditorMode.preview,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Просмотр'),
                ),
              ],
              selected: <_EditorMode>{_mode},
              onSelectionChanged: (Set<_EditorMode> selection) {
                setState(() => _mode = selection.single);
              },
            ),
            const Spacer(),
            IconButton(
              tooltip: 'История версий',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) => _DocumentVersionsDialog(
                  controller: widget.controller,
                  readOnly: widget.readOnly,
                ),
              ),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        if (_mode == _EditorMode.source) ...<Widget>[
          const SizedBox(height: 8),
          _buildFormattingToolbar(context),
        ],
        const Divider(),
        Expanded(child: _buildDocumentBody(context)),
        const Divider(height: 1),
        _AttachmentsPanel(
          controller: widget.controller,
          readOnly: widget.readOnly,
        ),
      ],
    ),
  );

  Widget _buildDocumentBody(BuildContext context) {
    if (_mode == _EditorMode.source) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _redo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        },
        child: TextField(
          key: const ValueKey<String>('document-editor-source'),
          controller: _content,
          focusNode: _contentFocus,
          readOnly: widget.readOnly,
          onChanged: widget.readOnly ? null : _changed,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Начните писать…',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      );
    }
    if (_content.text.trim().isEmpty) {
      return const Center(
        key: ValueKey<String>('document-editor-preview-empty'),
        child: Text('Документ пока пуст'),
      );
    }
    return Markdown(
      key: const ValueKey<String>('document-editor-preview'),
      data: _content.text,
      selectable: true,
      padding: const EdgeInsets.symmetric(vertical: 20),
      imageBuilder: _blockedMarkdownImage,
    );
  }

  Widget _buildFormattingToolbar(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('editor-undo'),
                tooltip: 'Отменить (Ctrl+Z)',
                onPressed: !widget.readOnly && _undoStack.isNotEmpty
                    ? _undo
                    : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton(
                key: const ValueKey<String>('editor-redo'),
                tooltip: 'Повторить (Ctrl+Y)',
                onPressed: !widget.readOnly && _redoStack.isNotEmpty
                    ? _redo
                    : null,
                icon: const Icon(Icons.redo, size: 20),
              ),
              const VerticalDivider(indent: 8, endIndent: 8),
              PopupMenuButton<int>(
                key: const ValueKey<String>('editor-heading'),
                tooltip: 'Стиль текста',
                enabled: !widget.readOnly,
                onSelected: _setHeading,
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<int>>[
                      PopupMenuItem<int>(
                        value: 0,
                        child: Text('Обычный текст'),
                      ),
                      PopupMenuItem<int>(value: 1, child: Text('Заголовок 1')),
                      PopupMenuItem<int>(value: 2, child: Text('Заголовок 2')),
                      PopupMenuItem<int>(value: 3, child: Text('Заголовок 3')),
                    ],
                icon: const Icon(Icons.title, size: 20),
              ),
              _formatButton(
                tooltip: 'Жирный',
                icon: Icons.format_bold,
                onPressed: () =>
                    _wrapSelection('**', '**', placeholder: 'жирный текст'),
              ),
              _formatButton(
                tooltip: 'Курсив',
                icon: Icons.format_italic,
                onPressed: () =>
                    _wrapSelection('_', '_', placeholder: 'курсив'),
              ),
              _formatButton(
                tooltip: 'Зачёркнутый',
                icon: Icons.strikethrough_s,
                onPressed: () =>
                    _wrapSelection('~~', '~~', placeholder: 'текст'),
              ),
              _formatButton(
                tooltip: 'Строчный код',
                icon: Icons.code,
                onPressed: () => _wrapSelection('`', '`', placeholder: 'код'),
              ),
              _formatButton(
                tooltip: 'Ссылка',
                icon: Icons.link,
                onPressed: () => _wrapSelection(
                  '[',
                  '](https://)',
                  placeholder: 'текст ссылки',
                ),
              ),
              const VerticalDivider(indent: 8, endIndent: 8),
              _formatButton(
                tooltip: 'Маркированный список',
                icon: Icons.format_list_bulleted,
                onPressed: () => _toggleLinePrefix('- '),
              ),
              _formatButton(
                tooltip: 'Нумерованный список',
                icon: Icons.format_list_numbered,
                onPressed: _toggleNumberedList,
              ),
              _formatButton(
                tooltip: 'Список задач',
                icon: Icons.checklist,
                onPressed: () => _toggleLinePrefix('- [ ] '),
              ),
              _formatButton(
                tooltip: 'Цитата',
                icon: Icons.format_quote,
                onPressed: () => _toggleLinePrefix('> '),
              ),
              _formatButton(
                tooltip: 'Блок кода',
                icon: Icons.data_object,
                onPressed: () =>
                    _wrapSelection('```\n', '\n```', placeholder: 'код'),
              ),
              _formatButton(
                tooltip: 'Разделитель',
                icon: Icons.horizontal_rule,
                onPressed: () => _insertText('\n\n---\n\n'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: widget.readOnly ? null : onPressed,
    icon: Icon(icon, size: 20),
  );
}

final class _DocumentVersionsDialog extends StatefulWidget {
  const _DocumentVersionsDialog({
    required this.controller,
    required this.readOnly,
  });

  final AppController controller;
  final bool readOnly;

  @override
  State<_DocumentVersionsDialog> createState() =>
      _DocumentVersionsDialogState();
}

final class _DocumentVersionsDialogState
    extends State<_DocumentVersionsDialog> {
  late Future<List<JsonMap>> _versions;
  int? _restoringRevision;
  String? _error;

  @override
  void initState() {
    super.initState();
    _versions = widget.controller.listSelectedDocumentVersions();
  }

  void _reload() {
    setState(() {
      _error = null;
      _versions = widget.controller.listSelectedDocumentVersions();
    });
  }

  Future<void> _restore(JsonMap version) async {
    final int revision = requireInt(version, 'revision');
    setState(() {
      _restoringRevision = revision;
      _error = null;
    });
    try {
      await widget.controller.restoreDocumentVersion(version);
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Версия $revision восстановлена')),
      );
    } on LocalApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Не удалось восстановить версию.');
      }
    } finally {
      if (mounted) {
        setState(() => _restoringRevision = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: <Widget>[
        Icon(Icons.history),
        SizedBox(width: 10),
        Text('История версий'),
      ],
    ),
    content: SizedBox(
      width: 620,
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Каждое восстановление создаёт новую версию — предыдущий текст '
            'не теряется.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<JsonMap>>(
              future: _versions,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<JsonMap>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('Не удалось загрузить историю версий.'),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      );
                    }
                    final List<JsonMap> versions =
                        snapshot.data ?? const <JsonMap>[];
                    if (versions.isEmpty) {
                      return const Center(
                        child: Text('Сохранённых версий пока нет.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: versions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) =>
                          _DocumentVersionCard(
                            version: versions[index],
                            readOnly: widget.readOnly,
                            restoring:
                                _restoringRevision ==
                                requireInt(versions[index], 'revision'),
                            onRestore: () => _restore(versions[index]),
                          ),
                    );
                  },
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}

final class _DocumentVersionCard extends StatelessWidget {
  const _DocumentVersionCard({
    required this.version,
    required this.readOnly,
    required this.restoring,
    required this.onRestore,
  });

  final JsonMap version;
  final bool readOnly;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final int revision = requireInt(version, 'revision');
    final bool current = version['is_current'] == true;
    final String content = requireString(version, 'content').trim();
    final String preview = content.isEmpty
        ? 'Пустой документ'
        : content.length > 180
        ? '${content.substring(0, 180)}…'
        : content;
    final DateTime? createdAt = DateTime.tryParse(
      requireString(version, 'created_at'),
    )?.toLocal();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Версия $revision',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (current)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Текущая'),
                  ),
                const Spacer(),
                Text(
                  _formatVersionDate(createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Text(
              requireString(version, 'title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 6),
            Text(
              preview.replaceAll('\n', ' '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!current) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: readOnly || restoring ? null : onRestore,
                  icon: restoring
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore, size: 18),
                  label: const Text('Восстановить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatVersionDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

Widget _blockedMarkdownImage(Uri uri, String? title, String? alt) => Tooltip(
  message: 'Изображения не загружаются в режиме просмотра',
  child: Text('[Изображение: ${alt?.trim().isNotEmpty == true ? alt : uri}]'),
);

final class _AiPanel extends StatefulWidget {
  const _AiPanel({required this.controller, required this.readOnly});

  final AppController controller;
  final bool readOnly;

  @override
  State<_AiPanel> createState() => _AiPanelState();
}

final class _AiPanelState extends State<_AiPanel> {
  final TextEditingController _instruction = TextEditingController();
  late final FocusNode _instructionFocus;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _instructionFocus = FocusNode(onKeyEvent: _handleInstructionKey);
    _instruction.addListener(_instructionChanged);
  }

  void _instructionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _instruction.removeListener(_instructionChanged);
    _instruction.dispose();
    _instructionFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleInstructionKey(FocusNode node, KeyEvent event) {
    final bool enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is KeyDownEvent && enter && _canEditInstruction) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _insertInstructionNewline();
      } else if (_instruction.text.trim().isNotEmpty) {
        unawaited(_send());
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertInstructionNewline() {
    final TextEditingValue value = _instruction.value;
    final TextSelection selection =
        value.selection.isValid &&
            value.selection.start <= value.text.length &&
            value.selection.end <= value.text.length
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final String text = value.text.replaceRange(
      selection.start,
      selection.end,
      '\n',
    );
    _instruction.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
  }

  bool get _canEditInstruction {
    final AppController controller = widget.controller;
    final JsonMap? document = controller.selectedDocument;
    return controller.aiAvailability == DocumentAiAvailability.ready &&
        !widget.readOnly &&
        !_sending &&
        !controller.aiRunning &&
        document != null &&
        document['document_type'] != 'plain';
  }

  Future<void> _send() async {
    final String instruction = _instruction.text.trim();
    if (instruction.isEmpty || _sending || widget.controller.aiRunning) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _runUiActionAsync(
        context,
        () => widget.controller.runDocumentAi(instruction),
      );
      if (mounted && widget.controller.aiError == null) {
        _instruction.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final JsonMap document = controller.selectedDocument!;
    final String documentType = document['document_type'] as String? ?? 'plain';
    final bool canEdit = _canEditInstruction;
    final bool canSend = canEdit && _instruction.text.trim().isNotEmpty;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Text(
                  'AI-помощник',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть AI-панель',
                  onPressed: () => controller.setAiPanelOpen(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: documentType,
              decoration: const InputDecoration(
                labelText: 'Тип документа',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'plain',
                  child: Text('Не выбран'),
                ),
                DropdownMenuItem<String>(value: 'adr', child: Text('ADR')),
                DropdownMenuItem<String>(
                  value: 'business_need',
                  child: Text('Business Need'),
                ),
                DropdownMenuItem<String>(value: 'rfc', child: Text('RFC')),
              ],
              onChanged: widget.readOnly || controller.aiRunning
                  ? null
                  : (String? value) {
                      if (value != null && value != documentType) {
                        _runUiAction(
                          context,
                          () => controller.setSelectedDocumentType(value),
                        );
                      }
                    },
            ),
            const SizedBox(height: 12),
            _AiAvailabilityView(controller: controller),
            if (controller.aiError != null) ...<Widget>[
              const SizedBox(height: 8),
              MaterialBanner(
                content: Text(controller.aiError!),
                actions: <Widget>[
                  TextButton(
                    onPressed: controller.checkAiAvailability,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: controller.aiMessages.isEmpty
                  ? const Center(
                      child: Text(
                        'Опишите идею или попросите Codex улучшить текущий '
                        'документ.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.aiMessages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final AiConversationMessage message =
                            controller.aiMessages[index];
                        final bool user = message.role == AiMessageRole.user;
                        return Align(
                          alignment: user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: user
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(message.text),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (controller.aiRunning) ...<Widget>[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey<String>('ai-instruction'),
              controller: _instruction,
              focusNode: _instructionFocus,
              minLines: 2,
              maxLines: 5,
              enabled: canEdit,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: documentType == 'plain'
                    ? 'Сначала выберите тип документа'
                    : 'Что сделать с документом?',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: canSend ? (_) => unawaited(_send()) : null,
            ),
            const SizedBox(height: 8),
            Row(
              key: const ValueKey<String>('ai-actions'),
              children: <Widget>[
                if (controller.canUndoAiEdit)
                  Tooltip(
                    message: 'Отменить AI-правку',
                    child: TextButton.icon(
                      key: const ValueKey<String>('ai-undo'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: controller.aiRunning
                          ? null
                          : () => _runUiAction(context, controller.undoAiEdit),
                      icon: const Icon(Icons.undo),
                      label: const Text('Отменить'),
                    ),
                  ),
                const Spacer(),
                if (controller.aiRunning)
                  OutlinedButton(
                    onPressed: controller.cancelDocumentAi,
                    child: const Text('Остановить'),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey<String>('ai-send'),
                    onPressed: canSend ? _send : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Отправить'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _AiAvailabilityView extends StatelessWidget {
  const _AiAvailabilityView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.aiChecking) {
      return const Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Проверяем локальный Codex…'),
        ],
      );
    }
    final String text = switch (controller.aiAvailability) {
      DocumentAiAvailability.ready => 'Codex готов',
      DocumentAiAvailability.missing =>
        'Codex не найден. Установите Codex и выполните codex login.',
      DocumentAiAvailability.authRequired =>
        'Требуется авторизация. Выполните codex login.',
      DocumentAiAvailability.unavailable => 'Codex временно недоступен.',
      DocumentAiAvailability.unknown => 'Codex ещё не проверен.',
    };
    return Row(
      children: <Widget>[
        Icon(
          controller.aiAvailability == DocumentAiAvailability.ready
              ? Icons.check_circle_outline
              : Icons.info_outline,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        if (controller.aiAvailability != DocumentAiAvailability.ready)
          IconButton(
            tooltip: 'Проверить Codex',
            onPressed: controller.checkAiAvailability,
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}

final class _AttachmentsPanel extends StatelessWidget {
  const _AttachmentsPanel({required this.controller, required this.readOnly});

  final AppController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Вложения', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Добавить вложение',
              onPressed: readOnly
                  ? null
                  : () => _addAttachment(context, controller),
              icon: const Icon(Icons.attach_file),
            ),
          ],
        ),
        if (controller.attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Нет вложений'),
          )
        else
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final JsonMap attachment = controller.attachments[index];
                return SizedBox(
                  width: 280,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        requireString(attachment, 'file_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatBytes(requireInt(attachment, 'size')),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Сохранить вложение',
                            onPressed: () => _downloadAttachment(
                              context,
                              controller,
                              attachment,
                            ),
                            icon: const Icon(Icons.download_outlined),
                          ),
                          if (!readOnly)
                            IconButton(
                              tooltip: 'Удалить вложение',
                              onPressed: () => _deleteAttachment(
                                context,
                                controller,
                                attachment,
                              ),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

final class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state, required this.onSave});

  final _SaveState state;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) => switch (state) {
    _SaveState.saved => const Chip(
      avatar: Icon(Icons.check_circle_outline, size: 18),
      label: Text('Сохранено локально'),
    ),
    _SaveState.pending => ActionChip(
      avatar: const Icon(Icons.schedule, size: 18),
      label: const Text('Есть изменения'),
      onPressed: onSave,
    ),
    _SaveState.saving => const Chip(
      avatar: SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: Text('Сохраняем…'),
    ),
    _SaveState.failed => ActionChip(
      avatar: const Icon(Icons.error_outline, size: 18),
      label: const Text('Повторить сохранение'),
      onPressed: onSave,
    ),
    _SaveState.conflict => const Chip(
      avatar: Icon(Icons.sync_problem, size: 18),
      label: Text('Конфликт'),
    ),
  };
}

Future<void> _createWorkspace(
  BuildContext context,
  AppController controller,
) async {
  final String? name = await _askText(
    context,
    title: 'Новое пространство',
    hint: 'Например, Личное',
  );
  if (name != null && name.trim().isNotEmpty && context.mounted) {
    _runUiAction(context, () => controller.createWorkspace(name));
  }
}

Future<void> _renameWorkspace(
  BuildContext context,
  AppController controller,
) async {
  final JsonMap? workspace = controller.selectedWorkspace;
  if (workspace == null) {
    return;
  }
  final String? name = await _askText(
    context,
    title: 'Переименовать пространство',
    hint: requireString(workspace, 'name'),
  );
  if (name != null && name.trim().isNotEmpty && context.mounted) {
    await _runUiActionAsync(
      context,
      () => controller.renameSelectedWorkspace(name),
    );
  }
}

Future<void> _setWorkspaceArchived(
  BuildContext context,
  AppController controller,
  bool archived,
) => _runUiActionAsync(
  context,
  () => controller.setSelectedWorkspaceArchived(archived),
);

Future<void> _deleteWorkspace(
  BuildContext context,
  AppController controller,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Удалить пространство?'),
      content: const Text(
        'Все документы пространства будут удалены локально. '
        'Это действие нельзя отменить в приложении.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _runUiActionAsync(context, controller.deleteSelectedWorkspace);
  }
}

Future<void> _createDocument(
  BuildContext context,
  AppController controller, {
  String? parentId,
}) async {
  String title = '';
  String documentType = 'plain';
  final _NewDocumentDraft? draft = await showDialog<_NewDocumentDraft>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text(parentId == null ? 'Новый документ' : 'Вложенный документ'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Название документа',
                ),
                onChanged: (String value) => title = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: documentType,
                decoration: const InputDecoration(
                  labelText: 'Тип документа',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'plain',
                    child: Text('Обычный документ'),
                  ),
                  DropdownMenuItem<String>(value: 'adr', child: Text('ADR')),
                  DropdownMenuItem<String>(
                    value: 'business_need',
                    child: Text('Business Need'),
                  ),
                  DropdownMenuItem<String>(value: 'rfc', child: Text('RFC')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => documentType = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _NewDocumentDraft(title: title, documentType: documentType),
            ),
            child: const Text('Создать'),
          ),
        ],
      ),
    ),
  );
  if (draft != null && draft.title.trim().isNotEmpty && context.mounted) {
    _runUiAction(
      context,
      () => controller.createDocument(
        draft.title,
        parentId: parentId,
        documentType: draft.documentType,
      ),
    );
  }
}

final class _NewDocumentDraft {
  const _NewDocumentDraft({required this.title, required this.documentType});

  final String title;
  final String documentType;
}

Future<void> _moveDocument(
  BuildContext context,
  AppController controller,
  JsonMap document,
) async {
  final String documentId = requireString(document, 'document_id');
  String selectedParent = (document['parent_id'] as String?) ?? '';
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: const Text('Переместить документ'),
        content: DropdownButtonFormField<String>(
          initialValue: selectedParent,
          decoration: const InputDecoration(labelText: 'Родитель'),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('В корень')),
            ...controller
                .validParentsFor(documentId)
                .map(
                  (JsonMap candidate) => DropdownMenuItem<String>(
                    value: requireString(candidate, 'document_id'),
                    child: Text(requireString(candidate, 'title')),
                  ),
                ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => selectedParent = value);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selectedParent),
            child: const Text('Переместить'),
          ),
        ],
      ),
    ),
  );
  if (result != null && context.mounted) {
    _runUiAction(
      context,
      () => controller.moveDocument(
        documentId: documentId,
        parentId: result.isEmpty ? null : result,
      ),
    );
  }
}

Future<void> _deleteDocument(
  BuildContext context,
  AppController controller,
  String documentId,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Удалить документ?'),
      content: const Text(
        'Документ и вложенные документы попадут в корзину. '
        'Их можно восстановить.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    _runUiAction(context, () => controller.deleteDocument(documentId));
  }
}

Future<void> _addAttachment(
  BuildContext context,
  AppController controller,
) async {
  final String? sourcePath = await _askText(
    context,
    title: 'Добавить вложение',
    hint: 'Полный путь к локальному файлу',
    confirmLabel: 'Добавить',
  );
  if (sourcePath != null && sourcePath.trim().isNotEmpty && context.mounted) {
    await _runUiActionAsync(
      context,
      () => controller.addAttachmentFromPath(
        sourcePath,
        mediaType: _mediaTypeForPath(sourcePath),
      ),
    );
  }
}

Future<void> _downloadAttachment(
  BuildContext context,
  AppController controller,
  JsonMap attachment,
) async {
  final String? targetPath = await _askText(
    context,
    title: 'Сохранить вложение',
    hint: requireString(attachment, 'file_name'),
    confirmLabel: 'Сохранить',
  );
  if (targetPath != null && targetPath.trim().isNotEmpty && context.mounted) {
    await _runUiActionAsync(
      context,
      () => controller.downloadAttachmentToPath(
        requireString(attachment, 'attachment_id'),
        targetPath,
      ),
    );
  }
}

Future<void> _deleteAttachment(
  BuildContext context,
  AppController controller,
  JsonMap attachment,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Удалить вложение?'),
      content: Text(requireString(attachment, 'file_name')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _runUiActionAsync(
      context,
      () => controller.deleteAttachment(
        requireString(attachment, 'attachment_id'),
      ),
    );
  }
}

void _runUiAction(BuildContext context, Future<void> Function() action) {
  unawaited(_runUiActionAsync(context, action));
}

Future<void> _runUiActionAsync(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on LocalApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выполнить локальную операцию.'),
        ),
      );
    }
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Создать',
}) async {
  String value = '';
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onChanged: (String changed) => value = changed,
        onSubmitted: (String submitted) => Navigator.pop(context, submitted),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes Б';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

String _mediaTypeForPath(String path) {
  final String normalized = path.toLowerCase();
  if (normalized.endsWith('.txt') || normalized.endsWith('.md')) {
    return 'text/plain';
  }
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.pdf')) {
    return 'application/pdf';
  }
  return 'application/octet-stream';
}
