import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/ask_screen.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/trips_screen.dart';
import 'ui/theme.dart';
import 'ui/voice_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await AppState.I.init();
  runApp(const TaraApp());
}

class TaraApp extends StatelessWidget {
  const TaraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tara',
        debugShowCheckedModeBanner: false,
        theme: T.theme(),
        home: ListenableBuilder(
          listenable: AppState.I,
          builder: (context, _) {
            final s = AppState.I;
            if (!s.modelsReady && !s.aiSkipped) return const OnboardingScreen();
            return const Shell();
          },
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  static ShellState of(BuildContext context) => context.findAncestorStateOfType<ShellState>()!;
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int tab = 0;

  void go(int i) => setState(() => tab = i);

  void openAsk([String? question]) {
    setState(() => tab = 1);
    if (question != null) AppState.I.askRequest.value = question;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const AskScreen(),
      const SizedBox(),
      const TripsScreen(),
      const GameScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: _Nav(
        tab: tab,
        onTap: (i) {
          if (i == 2) {
            showVoiceSheet(context);
          } else {
            go(i);
          }
        },
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.chat_bubble_outline, Icons.chat_bubble, 'Tanong'),
      (Icons.mic, Icons.mic, 'Tara'),
      (Icons.route_outlined, Icons.route, 'Trips'),
      (Icons.emoji_events_outlined, Icons.emoji_events, 'Pasada'),
    ];
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: T.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: i == 2
                    ? Center(
                        child: Semantics(
                          button: true,
                          label: 'Talk to Tara',
                          child: GestureDetector(
                            onTap: () => onTap(2),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: T.ink,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Color(0x3317233C), blurRadius: 14, offset: Offset(0, 5))],
                              ),
                              child: const Icon(Icons.mic, color: T.lime, size: 28),
                            ),
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: () => onTap(i),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(tab == i ? items[i].$2 : items[i].$1, color: tab == i ? T.olive : T.faint, size: 25),
                          const SizedBox(height: 3),
                          Text(items[i].$3,
                              style: T.b(12, color: tab == i ? T.olive : T.faint, w: tab == i ? FontWeight.w700 : FontWeight.w500)),
                        ]),
                      ),
              ),
          ]),
        ),
      ),
    );
  }
}
