import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snorec/models/recording.dart';
import 'package:snorec/services/storage_service.dart';
import 'package:snorec/utils/categories.dart';

class DiskStorage extends StorageService {
  final File file;
  DiskStorage(this.file);
  @override
  Future<File> indexFile() async => file;
}

Recording clip(int id) => Recording(
  id: '$id',
  filePath: 'missing-$id.wav',
  startedAt: DateTime(2026, 11, 27, 1, id),
  durationMs: 1000,
  peakDb: -20,
  avgDb: -30,
  category: SoundCategory.unknown,
  categoryLabel: 'Other',
  categoryConfidence: 0,
  waveform: const [],
);

void main() {
  test(
    'overlapping saves and classification updates preserve every clip',
    () async {
      final dir = await Directory.systemTemp.createTemp('snorec-index-');
      try {
        final file = await File('${dir.path}/index.json').writeAsString('[]');
        final a = DiskStorage(file);
        final b = DiskStorage(file);
        await Future.wait(
          List.generate(30, (i) => (i.isEven ? a : b).add(clip(i))),
        );
        expect(await a.loadAll(), hasLength(30));
        await Future.wait([
          a.update(clip(0).copyWith(categoryLabel: 'Talking')),
          b.add(clip(30)),
          a.delete(clip(1)),
        ]);
        final recordings = await b.loadAll();
        expect(recordings, hasLength(30));
        expect(
          recordings.singleWhere((r) => r.id == '0').categoryLabel,
          'Talking',
        );
        expect(recordings.any((r) => r.id == '1'), isFalse);
        expect(recordings.any((r) => r.id == '30'), isTrue);
        expect(await File('${file.path}.tmp').exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
