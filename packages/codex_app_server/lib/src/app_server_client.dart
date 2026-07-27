import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef CodexJsonMap = Map<String, Object?>;

String redactCodexDiagnostic(String line) {
  final RegExpMatch? severity = RegExp(
    r'\b(error|warning|panic)\b',
    caseSensitive: false,
  ).firstMatch(line);
  return severity == null
      ? 'codex-stderr'
      : 'codex-stderr:${severity.group(1)!.toLowerCase()}';
}

final class CodexException implements Exception {
  const CodexException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CodexException($code): $message';
}

final class CodexRuntime {
  const CodexRuntime({
    required this.executable,
    required this.version,
    required this.supportsStrictConfig,
  });

  final String executable;
  final String version;
  final bool supportsStrictConfig;
}

final class CodexRuntimeDiscovery {
  const CodexRuntimeDiscovery();

  Future<CodexRuntime> discover() async {
    final String? override = Platform.environment['ENDLESS_CODEX_PATH'];
    final bool usesOverride = override != null && override.trim().isNotEmpty;
    final String executable = usesOverride
        ? File(override.trim()).absolute.path
        : await _findOnPath();
    if (usesOverride && !await File(executable).exists()) {
      throw const CodexException(
        'CodexNotFound',
        'Локальный Codex не установлен или недоступен.',
      );
    }
    final ProcessResult result;
    try {
      result = await Process.run(executable, const <String>[
        '--version',
      ]).timeout(const Duration(seconds: 10));
    } on Object {
      throw const CodexException(
        'CodexUnavailable',
        'Не удалось запустить локальный Codex.',
      );
    }
    if (result.exitCode != 0) {
      throw const CodexException(
        'CodexUnavailable',
        'Локальный Codex не отвечает на проверку версии.',
      );
    }
    final String version = '${result.stdout}'.trim();
    if (!version.startsWith('codex-cli ')) {
      throw const CodexException(
        'CodexUnsupported',
        'Установленная версия Codex не поддерживает app-server.',
      );
    }
    final ProcessResult help;
    try {
      help = await Process.run(executable, const <String>[
        'app-server',
        '--help',
      ]).timeout(const Duration(seconds: 10));
    } on Object {
      throw const CodexException(
        'CodexUnsupported',
        'Не удалось проверить протокол Codex app-server.',
      );
    }
    if (help.exitCode != 0) {
      throw const CodexException(
        'CodexUnsupported',
        'Установленная версия Codex не поддерживает app-server.',
      );
    }
    return CodexRuntime(
      executable: executable,
      version: version,
      supportsStrictConfig: '${help.stdout}'.contains('--strict-config'),
    );
  }

  Future<String> _findOnPath() async {
    final List<String> arguments = Platform.isWindows
        ? const <String>['codex.exe']
        : const <String>['codex'];
    final String command = Platform.isWindows ? 'where.exe' : 'which';
    try {
      final ProcessResult result = await Process.run(
        command,
        arguments,
      ).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        for (final String candidate in const LineSplitter().convert(
          '${result.stdout}',
        )) {
          final String path = candidate.trim();
          if (path.isNotEmpty && await File(path).exists()) {
            return File(path).absolute.path;
          }
        }
      }
    } on Object {
      // Mapped to a stable product error below.
    }
    throw const CodexException(
      'CodexNotFound',
      'Локальный Codex не установлен. Установите Codex и выполните codex login.',
    );
  }
}

abstract interface class CodexTransport {
  Stream<List<int>> get standardOutput;
  Stream<List<int>> get standardError;
  IOSink get standardInput;
  Future<int> get exitCode;
  void kill();
}

final class ProcessCodexTransport implements CodexTransport {
  ProcessCodexTransport(this._process);

  final Process _process;

  static Future<ProcessCodexTransport> start(CodexRuntime runtime) async {
    final Process process;
    try {
      process = await Process.start(runtime.executable, <String>[
        'app-server',
        if (runtime.supportsStrictConfig) '--strict-config',
        '-c',
        'service_tier="fast"',
        '-c',
        'web_search="disabled"',
        '-c',
        'features.shell_tool=false',
        '-c',
        'features.unified_exec=false',
        '-c',
        'features.multi_agent=false',
        '-c',
        'features.multi_agent_v2=false',
        '-c',
        'features.apps=false',
        '-c',
        'features.enable_mcp_apps=false',
        '-c',
        'features.remote_plugin=false',
        '-c',
        'features.plugins=false',
        '-c',
        'mcp_servers={}',
      ], mode: ProcessStartMode.normal);
    } on Object {
      throw const CodexException(
        'CodexUnavailable',
        'Не удалось запустить Codex app-server.',
      );
    }
    return ProcessCodexTransport(process);
  }

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Stream<List<int>> get standardError => _process.stderr;

  @override
  IOSink get standardInput => _process.stdin;

  @override
  Stream<List<int>> get standardOutput => _process.stdout;

  @override
  void kill() => _process.kill();
}

final class CodexAccount {
  const CodexAccount({required this.authenticated});

  final bool authenticated;
}

final class CodexTurnHandle {
  const CodexTurnHandle({
    required this.threadId,
    required this.turnId,
    required this.result,
  });

  final String threadId;
  final String turnId;
  final Future<String> result;
}

final class CodexAppServerClient {
  CodexAppServerClient._(
    this._transport,
    this.version,
    this._requestTimeout,
    this._turnTimeout,
  );

  final CodexTransport _transport;
  final String version;
  final Duration _requestTimeout;
  final Duration _turnTimeout;
  final Map<int, Completer<CodexJsonMap>> _pending =
      <int, Completer<CodexJsonMap>>{};
  final Map<String, StringBuffer> _turnDeltas = <String, StringBuffer>{};
  final Map<String, String> _turnFinalMessages = <String, String>{};
  final Map<String, Completer<CodexJsonMap>> _turnCompletions =
      <String, Completer<CodexJsonMap>>{};
  final Map<String, CodexJsonMap> _earlyTurnCompletions =
      <String, CodexJsonMap>{};
  final List<String> _safeStderr = <String>[];
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  int _nextId = 1;
  bool _closed = false;

  static Future<CodexAppServerClient> launch({
    CodexRuntimeDiscovery discovery = const CodexRuntimeDiscovery(),
  }) async {
    final CodexRuntime runtime = await discovery.discover();
    final ProcessCodexTransport transport = await ProcessCodexTransport.start(
      runtime,
    );
    return connect(transport, version: runtime.version);
  }

  static Future<CodexAppServerClient> connect(
    CodexTransport transport, {
    String version = 'test',
    Duration requestTimeout = const Duration(seconds: 30),
    Duration turnTimeout = const Duration(minutes: 5),
  }) async {
    final CodexAppServerClient client = CodexAppServerClient._(
      transport,
      version,
      requestTimeout,
      turnTimeout,
    );
    client._listen();
    try {
      await client._initialize();
      return client;
    } on Object {
      await client.close();
      rethrow;
    }
  }

  void _listen() {
    _stdoutSubscription = _transport.standardOutput
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleStreamFailure);
    _stderrSubscription = _transport.standardError
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          if (_safeStderr.length == 20) {
            _safeStderr.removeAt(0);
          }
          _safeStderr.add(redactCodexDiagnostic(line));
        });
    unawaited(
      _transport.exitCode.then((int code) {
        if (!_closed) {
          _failAll(
            CodexException(
              'CodexExited',
              'Codex app-server завершился с кодом $code.',
            ),
          );
        }
      }),
    );
  }

  Future<void> _initialize() async {
    await _request('initialize', <String, Object?>{
      'clientInfo': <String, Object?>{
        'name': 'endless_docs',
        'title': 'Endless Docs',
        'version': '0.1.0',
      },
    }, timeout: const Duration(seconds: 15));
    _send(<String, Object?>{
      'method': 'initialized',
      'params': <String, Object?>{},
    });
  }

  Future<CodexAccount> readAccount() async {
    final CodexJsonMap result = await _request(
      'account/read',
      <String, Object?>{'refreshToken': false},
    );
    final bool requiresAuth = result['requiresOpenaiAuth'] == true;
    return CodexAccount(
      authenticated: !requiresAuth || result['account'] is Map<String, Object?>,
    );
  }

  Future<String> startThread({
    required String workingDirectory,
    required String baseInstructions,
    required String developerInstructions,
  }) async {
    final CodexJsonMap result =
        await _request('thread/start', <String, Object?>{
          'cwd': workingDirectory,
          'baseInstructions': baseInstructions,
          'developerInstructions': developerInstructions,
          'sandbox': 'read-only',
          'approvalPolicy': 'never',
          'ephemeral': true,
        });
    final CodexJsonMap thread = _map(result, 'thread');
    return _string(thread, 'id');
  }

  Future<CodexTurnHandle> startTurn({
    required String threadId,
    required String input,
    required CodexJsonMap outputSchema,
  }) async {
    final CodexJsonMap response = await _request(
      'turn/start',
      <String, Object?>{
        'threadId': threadId,
        'input': <Object?>[
          <String, Object?>{'type': 'text', 'text': input},
        ],
        'outputSchema': outputSchema,
        'approvalPolicy': 'never',
        'sandboxPolicy': <String, Object?>{
          'type': 'readOnly',
          'networkAccess': false,
        },
      },
    );
    final String turnId = _string(_map(response, 'turn'), 'id');
    final Completer<CodexJsonMap> completion = Completer<CodexJsonMap>();
    _turnCompletions[turnId] = completion;
    final CodexJsonMap? early = _earlyTurnCompletions.remove(turnId);
    if (early != null) {
      completion.complete(early);
    }
    return CodexTurnHandle(
      threadId: threadId,
      turnId: turnId,
      result: _finishTurn(turnId, completion.future),
    );
  }

  Future<String> _finishTurn(
    String turnId,
    Future<CodexJsonMap> completion,
  ) async {
    final CodexJsonMap turn = _map(
      await completion.timeout(
        _turnTimeout,
        onTimeout: () => throw const CodexException(
          'CodexTimeout',
          'Codex не завершил ответ за отведённое время.',
        ),
      ),
      'turn',
    );
    final String status = _string(turn, 'status');
    if (status == 'interrupted') {
      throw const CodexException('CodexCanceled', 'Запрос Codex отменён.');
    }
    if (status != 'completed') {
      throw const CodexException(
        'CodexTurnFailed',
        'Codex не смог подготовить документ.',
      );
    }
    final String result =
        _turnFinalMessages.remove(turnId) ??
        _turnDeltas.remove(turnId)?.toString() ??
        '';
    _turnCompletions.remove(turnId);
    if (result.trim().isEmpty) {
      throw const CodexException(
        'CodexInvalidResponse',
        'Codex вернул пустой ответ.',
      );
    }
    return result;
  }

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await _request('turn/interrupt', <String, Object?>{
      'threadId': threadId,
      'turnId': turnId,
    });
  }

  Future<CodexJsonMap> _request(
    String method,
    CodexJsonMap params, {
    Duration? timeout,
  }) {
    if (_closed) {
      throw const CodexException(
        'CodexUnavailable',
        'Codex app-server уже остановлен.',
      );
    }
    final int id = _nextId++;
    final Completer<CodexJsonMap> completer = Completer<CodexJsonMap>();
    _pending[id] = completer;
    _send(<String, Object?>{'method': method, 'id': id, 'params': params});
    return completer.future.timeout(
      timeout ?? _requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw CodexException(
          'CodexTimeout',
          'Codex не ответил на запрос $method.',
        );
      },
    );
  }

  void _send(CodexJsonMap message) {
    _transport.standardInput.writeln(jsonEncode(message));
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      _failAll(
        const CodexException(
          'CodexProtocolError',
          'Codex app-server вернул повреждённое сообщение.',
        ),
      );
      return;
    }
    if (decoded is! Map<String, Object?>) {
      return;
    }
    final Object? id = decoded['id'];
    if (id is int && !decoded.containsKey('method')) {
      final Completer<CodexJsonMap>? completer = _pending.remove(id);
      if (completer == null) {
        return;
      }
      final Object? error = decoded['error'];
      if (error is Map<String, Object?>) {
        completer.completeError(
          CodexException(
            'CodexRequestFailed',
            error['message'] is String
                ? error['message']! as String
                : 'Codex отклонил запрос.',
          ),
        );
      } else {
        final Object? result = decoded['result'];
        if (result is Map<String, Object?>) {
          completer.complete(result);
        } else {
          completer.complete(<String, Object?>{});
        }
      }
      return;
    }
    final String? method = decoded['method'] as String?;
    final Object? rawParams = decoded['params'];
    final CodexJsonMap params = rawParams is Map<String, Object?>
        ? rawParams
        : <String, Object?>{};
    if (id != null && method != null) {
      _send(<String, Object?>{
        'id': id,
        'error': <String, Object?>{
          'code': -32601,
          'message': 'Server requests are disabled for document editing.',
        },
      });
      return;
    }
    switch (method) {
      case 'item/agentMessage/delta':
        final String? turnId = params['turnId'] as String?;
        final String? delta = params['delta'] as String?;
        if (turnId != null && delta != null) {
          _turnDeltas.putIfAbsent(turnId, StringBuffer.new).write(delta);
        }
      case 'item/completed':
        final String? turnId = params['turnId'] as String?;
        final Object? item = params['item'];
        if (turnId != null &&
            item is Map<String, Object?> &&
            item['type'] == 'agentMessage' &&
            item['text'] is String) {
          _turnFinalMessages[turnId] = item['text']! as String;
        }
      case 'turn/completed':
        final Object? rawTurn = params['turn'];
        if (rawTurn is Map<String, Object?> && rawTurn['id'] is String) {
          final String turnId = rawTurn['id']! as String;
          final Completer<CodexJsonMap>? completer = _turnCompletions[turnId];
          if (completer == null) {
            _earlyTurnCompletions[turnId] = params;
          } else if (!completer.isCompleted) {
            completer.complete(params);
          }
        }
    }
  }

  void _handleStreamFailure(Object error, StackTrace stackTrace) {
    _failAll(
      const CodexException(
        'CodexProtocolError',
        'Поток Codex app-server был неожиданно закрыт.',
      ),
    );
  }

  void _failAll(CodexException error) {
    for (final Completer<CodexJsonMap> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
    for (final Completer<CodexJsonMap> completer in _turnCompletions.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _turnCompletions.clear();
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _failAll(
      const CodexException('CodexUnavailable', 'Codex app-server остановлен.'),
    );
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    await _transport.standardInput.close();
    _transport.kill();
  }
}

CodexJsonMap _map(CodexJsonMap source, String key) {
  final Object? value = source[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  throw CodexException(
    'CodexProtocolError',
    'Codex response does not contain "$key".',
  );
}

String _string(CodexJsonMap source, String key) {
  final Object? value = source[key];
  if (value is String) {
    return value;
  }
  throw CodexException(
    'CodexProtocolError',
    'Codex response does not contain "$key".',
  );
}
