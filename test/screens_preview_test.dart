// Renders each screen to PNG (test/goldens/) so the UI can be reviewed
// without a device. Regenerate with: flutter test --update-goldens test/screens_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara/ai/brain.dart';
import 'package:tara/app_state.dart';
import 'package:tara/main.dart';
import 'package:tara/screens/ask_screen.dart';
import 'package:tara/screens/game_screen.dart';
import 'package:tara/screens/home_screen.dart';
import 'package:tara/screens/log_trip_screen.dart';
import 'package:tara/screens/trips_screen.dart';
import 'package:tara/ui/theme.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: T.theme(), home: child));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    await _loadFont('Manrope', ['assets/fonts/Manrope-SemiBold.ttf', 'assets/fonts/Manrope-Bold.ttf', 'assets/fonts/Manrope-ExtraBold.ttf']);
    await _loadFont('DMSans', [
      'assets/fonts/DMSans-Regular.ttf',
      'assets/fonts/DMSans-Medium.ttf',
      'assets/fonts/DMSans-SemiBold.ttf',
      'assets/fonts/DMSans-Bold.ttf'
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'D:/dev/flutter';
    await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
    AppState.I.preview();
  });

  Widget shell(Widget body, int tab) => Scaffold(
        body: body,
        bottomNavigationBar: Builder(builder: (c) => const SizedBox()),
      );

  testWidgets('home', (tester) async {
    await _pump(tester, const Shell());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.png'));
  });

  testWidgets('ask answer', (tester) async {
    final s = AppState.I;
    s.chat.clear();
    final a = await s.brain.ask('Uulan daw, aabot ba ako sa 8AM class ko kung mag-jeep?', s.ctx);
    s.chat.add(a);
    await _pump(tester, const Scaffold(body: AskScreen()));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ask.png'));
    expect(a.action, TaraAction.none);
  });

  testWidgets('game quests', (tester) async {
    await _pump(tester, const Scaffold(body: GameScreen()));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/game.png'));
  });

  testWidgets('trips', (tester) async {
    await _pump(tester, const TripsScreen());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/trips.png'));
  });

  testWidgets('log trip', (tester) async {
    await _pump(tester, const LogTripScreen());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/log.png'));
  });

  testWidgets('home only', (tester) async {
    await _pump(tester, const Scaffold(body: HomeScreen()));
  });
}
