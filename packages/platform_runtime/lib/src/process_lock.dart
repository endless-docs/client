import 'dart:io';

final class ProcessLock {
  ProcessLock._(this._file);

  final RandomAccessFile _file;

  static Future<ProcessLock> acquire(File lockFile) async {
    await lockFile.parent.create(recursive: true);
    final RandomAccessFile handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return ProcessLock._(handle);
    } on Object {
      await handle.close();
      rethrow;
    }
  }

  Future<void> release() async {
    await _file.unlock();
    await _file.close();
  }
}
