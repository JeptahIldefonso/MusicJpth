import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/tables/music_folders_table.dart';
import 'package:music_oasis/data/models/music_folder.dart';

void main() {
  group('MusicFolder.fromRow', () {
    test('reads a row that has never been scanned', () {
      final MusicFolder folder = MusicFolder.fromRow(<String, Object?>{
        MusicFoldersTable.id: 7,
        MusicFoldersTable.path: '/music',
        MusicFoldersTable.dateAdded: 1000,
        MusicFoldersTable.lastScanned: null,
      });

      expect(folder.id, 7);
      expect(folder.path, '/music');
      expect(folder.dateAdded, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(folder.lastScanned, isNull);
    });

    test('reads a scanned row', () {
      final MusicFolder folder = MusicFolder.fromRow(<String, Object?>{
        MusicFoldersTable.id: 1,
        MusicFoldersTable.path: '/music',
        MusicFoldersTable.dateAdded: 1000,
        MusicFoldersTable.lastScanned: 2000,
      });

      expect(folder.lastScanned, DateTime.fromMillisecondsSinceEpoch(2000));
    });

    test('compares by value', () {
      Map<String, Object?> row(int id) => <String, Object?>{
        MusicFoldersTable.id: id,
        MusicFoldersTable.path: '/music',
        MusicFoldersTable.dateAdded: 1000,
        MusicFoldersTable.lastScanned: null,
      };

      expect(MusicFolder.fromRow(row(1)), MusicFolder.fromRow(row(1)));
      expect(
        MusicFolder.fromRow(row(1)).hashCode,
        MusicFolder.fromRow(row(1)).hashCode,
      );
      expect(MusicFolder.fromRow(row(1)), isNot(MusicFolder.fromRow(row(2))));
    });
  });
}
