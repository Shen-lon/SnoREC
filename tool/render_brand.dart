// Run with: flutter test tool/render_brand.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snorec/utils/theme.dart';
import 'package:snorec/widgets/brand.dart';

void main() {
  test('render launcher assets from the shared vector mark', () async {
    for (final name in ['snorec', 'snorec_foreground', 'snorec_monochrome']) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (name == 'snorec') {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          Paint()..color = AppColors.background,
        );
      }
      canvas.translate(128, 128);
      SnorecMarkPainter(
        monochrome: name == 'snorec_monochrome',
      ).paint(canvas, const Size.square(768));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('assets/brand/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
