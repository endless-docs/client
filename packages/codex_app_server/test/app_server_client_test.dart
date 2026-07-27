import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_app_server/codex_app_server.dart';
import 'package:test/test.dart';

void main() {
  test('correlates JSONL responses and completes a streamed turn', () async {
    final _FakeTransport transport = _FakeTransport(
      turnResult: jsonEncode(<String, Object?>{
        'action': 'no_change',
        'message': 'Документ уже полный.',
        'questions': <String>[],
        'title': null,
        'content': null,
      }),
    );
    final CodexAppServerClient client = await CodexAppServerClient.connect(
      transport,
    );
    addTearDown(client.close);

    expect((await client.readAccount()).authenticated, isTrue);
    final String threadId = await client.startThread(
      workingDirectory: Directory.current.path,
      baseInstructions: 'base',
      developerInstructions: 'developer',
    );
    final CodexTurnHandle turn = await client.startTurn(
      threadId: threadId,
      input: 'Check',
      outputSchema: const <String, Object?>{'type': 'object'},
    );

    expect(await turn.result, contains('Документ уже полный'));
    expect(
      transport.receivedMethods,
      containsAll(<String>[
        'initialize',
        'account/read',
        'thread/start',
        'turn/start',
      ]),
    );
  });

  test('fails pending requests on malformed JSONL and process exit', () async {
    final _FakeTransport malformed = _FakeTransport(
      turnResult: '{}',
      ignoredMethods: <String>{'account/read'},
    );
    final CodexAppServerClient malformedClient =
        await CodexAppServerClient.connect(malformed);
    addTearDown(malformedClient.close);
    final Future<CodexAccount> malformedRequest = malformedClient.readAccount();
    await malformed.waitForMethod('account/read');
    malformed.sendMalformed();
    await expectLater(
      malformedRequest,
      throwsA(
        isA<CodexException>().having(
          (CodexException error) => error.code,
          'code',
          'CodexProtocolError',
        ),
      ),
    );

    final _FakeTransport exited = _FakeTransport(
      turnResult: '{}',
      ignoredMethods: <String>{'account/read'},
    );
    final CodexAppServerClient exitedClient =
        await CodexAppServerClient.connect(exited);
    addTearDown(exitedClient.close);
    final Future<CodexAccount> exitedRequest = exitedClient.readAccount();
    await exited.waitForMethod('account/read');
    exited.completeExit(17);
    await expectLater(
      exitedRequest,
      throwsA(
        isA<CodexException>().having(
          (CodexException error) => error.code,
          'code',
          'CodexExited',
        ),
      ),
    );
  });

  test('times out, interrupts a turn, and redacts diagnostics', () async {
    final _FakeTransport timedOut = _FakeTransport(
      turnResult: '{}',
      ignoredMethods: <String>{'account/read'},
    );
    final CodexAppServerClient timeoutClient =
        await CodexAppServerClient.connect(
          timedOut,
          requestTimeout: const Duration(milliseconds: 10),
        );
    addTearDown(timeoutClient.close);
    await expectLater(
      timeoutClient.readAccount(),
      throwsA(
        isA<CodexException>().having(
          (CodexException error) => error.code,
          'code',
          'CodexTimeout',
        ),
      ),
    );

    final _FakeTransport canceled = _FakeTransport(
      turnResult: '{}',
      autoCompleteTurn: false,
    );
    final CodexAppServerClient cancelClient =
        await CodexAppServerClient.connect(canceled);
    addTearDown(cancelClient.close);
    final CodexTurnHandle turn = await cancelClient.startTurn(
      threadId: 'thread-1',
      input: 'cancel',
      outputSchema: const <String, Object?>{'type': 'object'},
    );
    await cancelClient.interruptTurn(
      threadId: turn.threadId,
      turnId: turn.turnId,
    );
    canceled.completeTurn(status: 'interrupted');
    await expectLater(
      turn.result,
      throwsA(
        isA<CodexException>().having(
          (CodexException error) => error.code,
          'code',
          'CodexCanceled',
        ),
      ),
    );
    expect(canceled.receivedMethods, contains('turn/interrupt'));

    const String secret = 'user@example.com C:\\private\\document.md';
    expect(redactCodexDiagnostic(secret), 'codex-stderr');
    expect(redactCodexDiagnostic('ERROR $secret'), 'codex-stderr:error');
    expect(redactCodexDiagnostic(secret), isNot(contains('document')));
  });

  test(
    'document AI parses replacement and rejects oversized context',
    () async {
      final _FakeTransport transport = _FakeTransport(
        turnResult: jsonEncode(<String, Object?>{
          'action': 'replace_document',
          'message': 'Обновлено.',
          'questions': <String>[],
          'title': 'ADR: Хранилище',
          'content': '## Context\nЛокальное хранение.',
        }),
      );
      final CodexAppServerClient client = await CodexAppServerClient.connect(
        transport,
      );
      final CodexDocumentAi ai = CodexDocumentAi(
        clientFactory: () async => client,
      );
      addTearDown(ai.close);

      final DocumentAiResult result = await ai.run(
        snapshot: const DocumentAiSnapshot(
          documentType: 'adr',
          title: 'Черновик',
          content: '',
        ),
        instruction: 'Сформируй ADR',
      );

      expect(result.action, DocumentAiAction.replaceDocument);
      expect(result.title, 'ADR: Хранилище');

      await expectLater(
        ai.run(
          snapshot: DocumentAiSnapshot(
            documentType: 'adr',
            title: 'Большой',
            content: List<String>.filled(
              maximumAiContextCharacters,
              'x',
            ).join(),
          ),
          instruction: 'Обнови',
        ),
        throwsA(
          isA<CodexException>().having(
            (CodexException error) => error.code,
            'code',
            'AiContextTooLarge',
          ),
        ),
      );
    },
  );

  test('parses ask and no_change and rejects invalid output', () async {
    final DocumentAiResult ask = await _runStructuredResult(<String, Object?>{
      'action': 'ask',
      'message': 'Нужны детали.',
      'questions': <String>['Какой статус?'],
      'title': null,
      'content': null,
    });
    expect(ask.action, DocumentAiAction.ask);
    expect(ask.questions, <String>['Какой статус?']);

    final DocumentAiResult noChange =
        await _runStructuredResult(<String, Object?>{
          'action': 'no_change',
          'message': 'Изменения не нужны.',
          'questions': <String>[],
          'title': null,
          'content': null,
        });
    expect(noChange.action, DocumentAiAction.noChange);

    await expectLater(
      _runStructuredResult(<String, Object?>{
        'action': 'replace_document',
        'message': 'Неверный тип.',
        'questions': <String>[],
        'title': 42,
        'content': 'text',
      }),
      throwsA(
        isA<CodexException>().having(
          (CodexException error) => error.code,
          'code',
          'CodexInvalidResponse',
        ),
      ),
    );
  });

  test(
    'adds the required structure for every supported document type',
    () async {
      const Map<String, String> expectedGuidance = <String, String>{
        'adr': 'Context, Decision, Alternatives, Consequences',
        'business_need': 'Problem, Audience, Desired outcome',
        'rfc': 'Motivation, Proposal, Alternatives, Risks, Rollout',
      };
      for (final MapEntry<String, String> expectation
          in expectedGuidance.entries) {
        final _FakeTransport transport = _FakeTransport(
          turnResult: jsonEncode(<String, Object?>{
            'action': 'no_change',
            'message': 'ok',
            'questions': <String>[],
            'title': null,
            'content': null,
          }),
        );
        final CodexAppServerClient client = await CodexAppServerClient.connect(
          transport,
        );
        final CodexDocumentAi ai = CodexDocumentAi(
          clientFactory: () async => client,
        );
        await ai.run(
          snapshot: DocumentAiSnapshot(
            documentType: expectation.key,
            title: 'Synthetic title',
            content: 'Synthetic body',
          ),
          instruction: 'Review',
        );
        final Map<String, Object?> turnRequest = transport.receivedRequests
            .firstWhere(
              (Map<String, Object?> request) =>
                  request['method'] == 'turn/start',
            );
        final Map<String, Object?> params =
            turnRequest['params']! as Map<String, Object?>;
        final List<Object?> input = params['input']! as List<Object?>;
        final Map<String, Object?> textItem =
            input.single as Map<String, Object?>;
        expect(textItem['text'], contains(expectation.value));
        expect(params['outputSchema'], isA<Map<String, Object?>>());
        await ai.close();
      }
    },
  );
}

final class _FakeTransport implements CodexTransport {
  _FakeTransport({
    required this.turnResult,
    this.ignoredMethods = const <String>{},
    this.autoCompleteTurn = true,
  }) {
    _input.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleRequest);
  }

  final String turnResult;
  final Set<String> ignoredMethods;
  final bool autoCompleteTurn;
  final StreamController<List<int>> _input = StreamController<List<int>>();
  final StreamController<List<int>> _output = StreamController<List<int>>();
  final StreamController<List<int>> _error = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  late final IOSink _inputSink = IOSink(_input);
  final List<String> receivedMethods = <String>[];
  final List<Map<String, Object?>> receivedRequests = <Map<String, Object?>>[];

  Future<void> waitForMethod(String method) async {
    for (int attempt = 0; attempt < 100; attempt++) {
      if (receivedMethods.contains(method)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    fail('Method $method was not received.');
  }

  void sendMalformed() {
    _output.add(utf8.encode('{not-json}\n'));
  }

  void completeExit(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  void completeTurn({required String status}) {
    _send(<String, Object?>{
      'method': 'turn/completed',
      'params': <String, Object?>{
        'threadId': 'thread-1',
        'turn': <String, Object?>{
          'id': 'turn-1',
          'items': <Object?>[],
          'status': status,
        },
      },
    });
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<List<int>> get standardError => _error.stream;

  @override
  IOSink get standardInput => _inputSink;

  @override
  Stream<List<int>> get standardOutput => _output.stream;

  void _handleRequest(String line) {
    final Map<String, Object?> request =
        jsonDecode(line) as Map<String, Object?>;
    receivedRequests.add(request);
    final String method = request['method']! as String;
    receivedMethods.add(method);
    final Object? id = request['id'];
    if (id == null || ignoredMethods.contains(method)) {
      return;
    }
    switch (method) {
      case 'initialize':
        _send(<String, Object?>{'id': id, 'result': <String, Object?>{}});
      case 'account/read':
        _send(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'requiresOpenaiAuth': true,
            'account': <String, Object?>{
              'type': 'chatgpt',
              'email': 'test@example.com',
              'planType': 'plus',
            },
          },
        });
      case 'thread/start':
        _send(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'thread': <String, Object?>{'id': 'thread-1'},
          },
        });
      case 'turn/start':
        _send(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'turn': <String, Object?>{
              'id': 'turn-1',
              'items': <Object?>[],
              'status': 'inProgress',
            },
          },
        });
        if (!autoCompleteTurn) {
          return;
        }
        scheduleMicrotask(() {
          _send(<String, Object?>{
            'method': 'item/agentMessage/delta',
            'params': <String, Object?>{
              'threadId': 'thread-1',
              'turnId': 'turn-1',
              'itemId': 'item-1',
              'delta': turnResult.substring(0, turnResult.length ~/ 2),
            },
          });
          _send(<String, Object?>{
            'method': 'item/agentMessage/delta',
            'params': <String, Object?>{
              'threadId': 'thread-1',
              'turnId': 'turn-1',
              'itemId': 'item-1',
              'delta': turnResult.substring(turnResult.length ~/ 2),
            },
          });
          completeTurn(status: 'completed');
        });
      case 'turn/interrupt':
        _send(<String, Object?>{'id': id, 'result': <String, Object?>{}});
    }
  }

  void _send(Map<String, Object?> message) {
    final List<int> bytes = utf8.encode('${jsonEncode(message)}\n');
    final int split = bytes.length ~/ 2;
    _output
      ..add(bytes.sublist(0, split))
      ..add(bytes.sublist(split));
  }

  @override
  void kill() {
    if (!_exit.isCompleted) {
      _exit.complete(0);
    }
    unawaited(_output.close());
    unawaited(_error.close());
  }
}

Future<DocumentAiResult> _runStructuredResult(
  Map<String, Object?> structured,
) async {
  final _FakeTransport transport = _FakeTransport(
    turnResult: jsonEncode(structured),
  );
  final CodexAppServerClient client = await CodexAppServerClient.connect(
    transport,
  );
  final CodexDocumentAi ai = CodexDocumentAi(clientFactory: () async => client);
  try {
    return await ai.run(
      snapshot: const DocumentAiSnapshot(
        documentType: 'business_need',
        title: 'Need',
        content: 'Problem',
      ),
      instruction: 'Review',
    );
  } finally {
    await ai.close();
  }
}
