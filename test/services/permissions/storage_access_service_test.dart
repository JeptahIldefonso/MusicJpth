import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/services/permissions/storage_access_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('StorageAccessService', () {
    const StorageAccessService service = StorageAccessService();
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('music_oasis_access');
    });

    tearDown(() => temp.delete(recursive: true));

    test('reports a readable folder', () async {
      await File(p.join(temp.path, 'song.mp3')).writeAsString('');

      expect(await service.check(temp.path), FolderAccess.readable);
    });

    test('reports an empty folder as readable', () async {
      expect(await service.check(temp.path), FolderAccess.readable);
    });

    test('reports a folder that is gone as missing', () async {
      final String path = p.join(temp.path, 'never-existed');

      expect(await service.check(path), FolderAccess.missing);
    });
  });
}
