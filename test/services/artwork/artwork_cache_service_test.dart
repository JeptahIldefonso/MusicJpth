import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/services/artwork/artwork_cache_service.dart';

Uint8List bytes(List<int> list) => Uint8List.fromList(list);

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('artwork_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  ArtworkCacheService service() => ArtworkCacheService(baseDirOverride: temp);

  test('stores jpeg bytes once per unique content', () async {
    final jpeg = bytes(<int>[0xFF, 0xD8, 0xFF, 1, 2, 3]);
    final svc = service();

    final first = await svc.save(jpeg);
    expect(first, isNotNull);
    expect(first!.startsWith('artwork/'), isTrue);
    expect(first.endsWith('.jpg'), isTrue);
    expect(await File('${temp.path}/$first').exists(), isTrue);

    // Same content: same relative path, no second file.
    final again = await svc.save(jpeg);
    expect(again, first);
    final count = await Directory('${temp.path}/artwork').childrenCount();
    expect(count, 1);
  });

  test('different content gets different files', () async {
    final svc = service();
    final a = await svc.save(bytes(<int>[0xFF, 0xD8, 1]));
    final b = await svc.save(bytes(<int>[0x89, 0x50, 0x4E, 0x47, 9]));

    expect(a, isNot(b));
    expect(b!.endsWith('.png'), isTrue);
    expect(await Directory('${temp.path}/artwork').childrenCount(), 2);
  });

  test('rejects empty and unrecognised payloads', () async {
    final svc = service();
    expect(await svc.save(null), isNull);
    expect(await svc.save(Uint8List(0)), isNull);
    expect(await svc.save(bytes(<int>[1, 2, 3])), isNull);
  });

  test('resolve returns the file for stored paths only', () async {
    final svc = service();
    final relative = await svc.save(bytes(<int>[0xFF, 0xD8, 7, 7]));

    final resolved = await svc.resolve(relative);
    expect(resolved, isNotNull);
    expect(await resolved!.length(), 4);

    expect(await svc.resolve(null), isNull);
    expect(await svc.resolve('artwork/nope.jpg'), isNull);

    // Hashing is deterministic across calls.
    expect(
      ArtworkCacheService.fnv1a64Hex(bytes(<int>[9, 9, 9])),
      ArtworkCacheService.fnv1a64Hex(bytes(<int>[9, 9, 9])),
    );
  });
}

extension on Directory {
  Future<int> childrenCount() async => (await list().toList()).length;
}
