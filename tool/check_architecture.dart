import 'dart:io';

final class _Rule {
  const _Rule({required this.root, required this.forbiddenImports});

  final String root;
  final List<String> forbiddenImports;
}

void main() {
  final Directory repository = Directory.current.absolute;
  final List<_Rule> rules = <_Rule>[
    const _Rule(
      root: 'packages/client_domain',
      forbiddenImports: <String>[
        'package:flutter/',
        'package:isar',
        'package:local_api',
        'package:client_application',
      ],
    ),
    const _Rule(
      root: 'packages/client_application',
      forbiddenImports: <String>[
        'package:flutter/',
        'package:isar',
        'package:local_api',
        'package:persistence_isar',
      ],
    ),
    const _Rule(
      root: 'apps/endless_app',
      forbiddenImports: <String>[
        'package:isar',
        'package:persistence_isar',
        'package:client_domain',
        'package:client_application',
      ],
    ),
    const _Rule(
      root: 'apps/endless_cli',
      forbiddenImports: <String>[
        'package:isar',
        'package:persistence_isar',
        'package:client_domain',
        'package:client_application',
      ],
    ),
    const _Rule(
      root: 'packages/local_api_client',
      forbiddenImports: <String>[
        'package:isar',
        'package:persistence_isar',
        'package:client_domain',
        'package:client_application',
      ],
    ),
  ];
  final List<String> violations = <String>[];

  for (final _Rule rule in rules) {
    final Directory root = Directory(_join(repository.path, rule.root));
    for (final FileSystemEntity entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final String forbidden in rule.forbiddenImports) {
        if (source.contains("'$forbidden") || source.contains('"$forbidden')) {
          violations.add(
            '${_relative(repository.path, entity.path)} imports $forbidden',
          );
        }
      }
    }
  }

  final Directory packages = Directory(_join(repository.path, 'packages'));
  final Directory apps = Directory(_join(repository.path, 'apps'));
  for (final Directory searchRoot in <Directory>[packages, apps]) {
    for (final FileSystemEntity entity in searchRoot.listSync(
      recursive: true,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll('\\', '/');
      final bool allowed =
          normalized.contains('/packages/persistence_isar/') ||
          normalized.endsWith('/apps/locald/lib/src/locald_server.dart');
      if (!allowed &&
          entity.readAsStringSync().contains('package:isar_community/')) {
        violations.add(
          '${_relative(repository.path, entity.path)} imports Isar outside '
          'the persistence boundary',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Architecture boundary violations:');
    for (final String violation in violations) {
      stderr.writeln('- $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Architecture boundaries: OK');
}

String _join(String left, String right) =>
    '$left${Platform.pathSeparator}${right.replaceAll('/', Platform.pathSeparator)}';

String _relative(String root, String path) =>
    path.substring(root.length + 1).replaceAll('\\', '/');
