import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara/app_state.dart';
import 'package:tara/ui/profile.dart';
import 'package:tara/ui/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  testWidgets('profile sheet renders', (tester) async {
    await _font('Manrope', ['assets/fonts/Manrope-ExtraBold.ttf']);
    await _font('DMSans', ['assets/fonts/DMSans-Regular.ttf', 'assets/fonts/DMSans-SemiBold.ttf', 'assets/fonts/DMSans-Bold.ttf']);
    await _font('MaterialIcons', ['D:/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
    AppState.I.preview();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(MaterialApp(
      theme: T.theme(),
      home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => showProfileSheet(c), child: const Text('open'))))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile.png'));
  });
}
