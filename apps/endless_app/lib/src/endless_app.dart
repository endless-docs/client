import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_api/local_api.dart';

import 'app_controller.dart';

final class EndlessApp extends StatelessWidget {
  const EndlessApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Endless Docs',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff5f5ce6),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff9b99ff),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    ),
    home: _Home(controller: controller),
  );
}

final class _Home extends StatelessWidget {
  const _Home({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? child) =>
        switch (controller.phase) {
          AppPhase.starting => const _StartingView(),
          AppPhase.failed => _FailureView(
            message: controller.errorMessage ?? 'Неизвестная ошибка',
            onRetry: controller.initialize,
          ),
          AppPhase.ready => _ReadyView(controller: controller),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Запускаем локальное хранилище…'),
          ],
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.storage_rounded, size: 56),
              const SizedBox(height: 20),
              Text(
                'Локальное хранилище недоступно',
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
  );
}

final class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Endless Docs'),
      actions: const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Chip(
            avatar: Icon(Icons.cloud_off_rounded, size: 18),
            label: Text('Локально'),
          ),
        ),
      ],
    ),
    body: Row(
      children: <Widget>[
        SizedBox(width: 300, child: _NavigationPane(controller: controller)),
        const VerticalDivider(width: 1),
        Expanded(
          child: controller.selectedDocument == null
              ? _EmptyDocumentView(controller: controller)
              : DocumentEditor(
                  key: ValueKey<String>(controller.selectedDocumentId!),
                  controller: controller,
                  document: controller.selectedDocument!,
                ),
        ),
      ],
    ),
  );
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
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
                                    requireString(workspace, 'name'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              controller.selectWorkspace(value);
                            }
                          },
                        ),
                      ),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('Документы')),
              IconButton(
                tooltip: 'Новый документ',
                onPressed: controller.selectedWorkspaceId == null
                    ? null
                    : () => _createDocument(context, controller),
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.documents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Создайте первый документ — интернет не требуется.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: controller.documents.length,
                  itemBuilder: (BuildContext context, int index) {
                    final JsonMap document = controller.documents[index];
                    final String id = requireString(document, 'document_id');
                    return ListTile(
                      selected: id == controller.selectedDocumentId,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        requireString(document, 'title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => controller.selectDocument(id),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

final class _EmptyDocumentView extends StatelessWidget {
  const _EmptyDocumentView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.edit_note_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          controller.selectedWorkspaceId == null
              ? 'Создайте локальное пространство'
              : 'Выберите или создайте документ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: controller.selectedWorkspaceId == null
              ? () => _createWorkspace(context, controller)
              : () => _createDocument(context, controller),
          child: Text(
            controller.selectedWorkspaceId == null
                ? 'Создать пространство'
                : 'Создать документ',
          ),
        ),
      ],
    ),
  );
}

enum _SaveState { saved, pending, saving, failed, conflict }

final class DocumentEditor extends StatefulWidget {
  const DocumentEditor({
    required this.controller,
    required this.document,
    super.key,
  });

  final AppController controller;
  final JsonMap document;

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

final class _DocumentEditorState extends State<DocumentEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late int _revision;
  String? _blockId;
  Timer? _autosave;
  _SaveState _state = _SaveState.saved;

  @override
  void initState() {
    super.initState();
    _readDocument(widget.document);
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
  }

  void _changed(String _) {
    _autosave?.cancel();
    setState(() => _state = _SaveState.pending);
    _autosave = Timer(const Duration(milliseconds: 700), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    if (_state == _SaveState.saving) {
      return;
    }
    _autosave?.cancel();
    setState(() => _state = _SaveState.saving);
    try {
      final JsonMap saved = await widget.controller.saveDocument(
        documentId: requireString(widget.document, 'document_id'),
        title: _title.text,
        text: _content.text,
        expectedRevision: _revision,
        blockId: _blockId,
      );
      if (!mounted) {
        return;
      }
      _revision = requireInt(saved, 'revision');
      final List<JsonMap> blocks = requireMapList(saved, 'blocks');
      _blockId = blocks.isEmpty ? null : blocks.first['block_id'] as String?;
      setState(() => _state = _SaveState.saved);
    } on LocalApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _state = error.code == 'RevisionConflict'
            ? _SaveState.conflict
            : _SaveState.failed,
      );
    } on Object {
      if (mounted) {
        setState(() => _state = _SaveState.failed);
      }
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 24, 40, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _title,
                onChanged: _changed,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: const InputDecoration(
                  hintText: 'Название',
                  border: InputBorder.none,
                ),
              ),
            ),
            _SaveIndicator(state: _state, onSave: _save),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Удалить документ',
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
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
        const Divider(),
        Expanded(
          child: TextField(
            controller: _content,
            onChanged: _changed,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Начните писать…',
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: const Text('Документ можно будет восстановить из корзины.'),
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
    if (confirmed == true) {
      await widget.controller.deleteSelectedDocument();
    }
  }
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
  if (name != null && name.trim().isNotEmpty) {
    await controller.createWorkspace(name);
  }
}

Future<void> _createDocument(
  BuildContext context,
  AppController controller,
) async {
  final String? title = await _askText(
    context,
    title: 'Новый документ',
    hint: 'Название документа',
  );
  if (title != null && title.trim().isNotEmpty) {
    await controller.createDocument(title);
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
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
          child: const Text('Создать'),
        ),
      ],
    ),
  );
}
