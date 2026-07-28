import 'dart:io';

import 'package:codex_app_server/codex_app_server.dart';

Future<void> main() async {
  CodexAppServerClient? client;
  CodexDocumentAi? ai;
  try {
    client = await CodexAppServerClient.launch();
    stdout.writeln('Codex runtime: ${client.version}');
    ai = CodexDocumentAi(clientFactory: () async => client!);
    final DocumentAiAvailability availability = await ai.checkAvailability();
    stdout.writeln('Codex availability: ${availability.name}');
    if (availability != DocumentAiAvailability.ready) {
      exitCode = 1;
      return;
    }

    int progressUpdates = 0;
    final Set<int> progressSections = <int>{};
    final DocumentAiResult result = await ai.run(
      snapshot: const DocumentAiSnapshot(
        documentType: 'adr',
        title: 'Local Codex smoke test',
        content: '''
# Status

Proposed

# Context

Verify the optional local Codex integration with synthetic content only.
''',
      ),
      instruction:
          'Review this synthetic ADR. Do not add facts. Return no_change '
          'with one short recommendation unless a clarification is required.',
      onProgress: (DocumentAiProgress progress) {
        progressUpdates += 1;
        if (progress.kind == DocumentAiProgressKind.reasoningSummary) {
          progressSections.add(progress.sectionIndex);
        }
      },
    );
    stdout
      ..writeln('Structured action: ${result.action.name}')
      ..writeln('Progress updates: $progressUpdates')
      ..writeln('Reasoning summary sections: ${progressSections.length}')
      ..writeln('Message characters: ${result.message.length}')
      ..writeln('Questions: ${result.questions.length}')
      ..writeln('Replacement title present: ${result.title != null}')
      ..writeln('Replacement body present: ${result.content != null}');
    if (progressUpdates == 0) {
      stderr.writeln('Codex smoke failed: no progress events received.');
      exitCode = 1;
    }
  } on CodexException catch (error) {
    stderr.writeln('Codex smoke failed: ${error.code} (${error.message})');
    exitCode = 1;
  } finally {
    await ai?.close();
    if (ai == null) {
      await client?.close();
    }
  }
}
