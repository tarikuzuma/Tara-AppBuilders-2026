// Generates demo barkada QR cards into demo/ (scan them with "From photo" or
// show on another screen). Run: flutter test test/tools/make_demo_qr_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tara/data/models.dart';
import 'package:tara/game/barkada_card.dart';
import 'package:tara/game/xp_engine.dart';

void main() {
  testWidgets('write demo friend QR cards', (tester) async {
    final week = isoWeek(DateTime.now());
    final friends = [
      Friend(name: 'Jolo', week: week, xp: 640, steps: 52300, streak: 5, level: 9, title: 'Campus Navigator', avatar: '🐸', color: 4),
      Friend(name: 'Andrea', week: week, xp: 1180, steps: 70100, streak: 11, level: 14, title: 'Street Smart', avatar: '👩‍💻', color: 5),
    ];
    Directory('demo').createSync();
    for (final f in friends) {
      await tester.runAsync(() async {
        final painter = QrPainter(data: encodeCard(f), version: QrVersions.auto, gapless: true,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF17233C)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF17233C)));
        final qr = await painter.toImage(720);
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(const Rect.fromLTWH(0, 0, 880, 880), Paint()..color = Colors.white);
        c.drawImage(qr, const Offset(80, 80), Paint());
        final img = await rec.endRecording().toImage(880, 880);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('demo/friend_qr_${f.name.toLowerCase()}.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    expect(File('demo/friend_qr_jolo.png').existsSync(), true);
  });
}
