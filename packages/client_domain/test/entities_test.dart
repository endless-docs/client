import 'package:client_domain/client_domain.dart';
import 'package:test/test.dart';

void main() {
  group('domain validation', () {
    test('normalizes names and rejects empty values', () {
      expect(validateWorkspaceName('  Personal  '), 'Personal');
      expect(
        () => validateWorkspaceName(' '),
        throwsA(
          isA<DomainException>().having(
            (DomainException error) => error.code,
            'code',
            'InvalidArgument',
          ),
        ),
      );
    });

    test('document update advances revision and preserves identity', () {
      final DateTime created = DateTime.utc(2026, 1, 1);
      final Document document = Document(
        id: 'document-1',
        workspaceId: 'workspace-1',
        title: 'Old',
        parentId: null,
        position: 0,
        blocks: const <Block>[],
        revision: 1,
        isDeleted: false,
        createdAt: created,
        updatedAt: created,
      );

      final Document updated = document.updateContent(
        title: 'New',
        blocks: const <Block>[],
        now: created.add(const Duration(minutes: 1)),
      );

      expect(updated.id, document.id);
      expect(updated.revision, 2);
      expect(updated.title, 'New');
    });

    test('workspace lifecycle advances revision without changing identity', () {
      final DateTime created = DateTime.utc(2026, 1, 1);
      final Workspace workspace = Workspace(
        id: 'workspace-1',
        name: 'Personal',
        lifecycle: WorkspaceLifecycle.active,
        revision: 1,
        createdAt: created,
        updatedAt: created,
      );

      final Workspace archived = workspace.changeLifecycle(
        WorkspaceLifecycle.archived,
        created.add(const Duration(minutes: 1)),
      );

      expect(archived.id, workspace.id);
      expect(archived.lifecycle, WorkspaceLifecycle.archived);
      expect(archived.revision, 2);
    });
  });
}
