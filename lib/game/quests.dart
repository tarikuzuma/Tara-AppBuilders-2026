import '../data/models.dart';
import 'xp_engine.dart';

/// A weekly quest. Code picks the target, tracks progress and pays the reward;
/// Tara (the AI) only writes the [title]/[pep] text.
class Quest {
  final String type;
  final int target;
  final int reward;
  final String unit;
  final String defaultTitle;
  final String description;
  int progress;
  String title;
  String pep;

  Quest({
    required this.type,
    required this.target,
    required this.reward,
    required this.unit,
    required this.defaultTitle,
    required this.description,
    this.progress = 0,
    String? title,
    this.pep = '',
  }) : title = title ?? defaultTitle;

  bool get done => progress >= target;
  double get fraction => (progress / target).clamp(0, 1).toDouble();
}

class QuestContext {
  final List<Trip> trips;
  final Map<DateTime, int> dailySteps; // day → steps
  final DateTime now;
  QuestContext(this.trips, this.dailySteps, this.now);

  List<Trip> get thisWeek {
    final start = weekStart(now);
    return trips.where((t) => !t.start.isBefore(start)).toList();
  }

  List<Trip> lastDays(int days) {
    final from = dayOf(now).subtract(Duration(days: days));
    return trips.where((t) => !t.start.isBefore(from)).toList();
  }
}

/// Pick up to three quests that fit this user's recent patterns.
List<Quest> pickQuests(QuestContext c) {
  final quests = <Quest>[];
  final recent = c.lastDays(14);

  final trikeTrips = recent.where((t) => t.mode == 'tricycle').length;
  if (trikeTrips >= 3) {
    quests.add(Quest(
      type: 'walk_instead',
      target: 3,
      reward: 180,
      unit: 'trips',
      defaultTitle: 'Lakad muna, bes!',
      description: 'Walk to the jeep stop instead of taking a trike.',
    ));
  }

  quests.add(Quest(
    type: 'log_days',
    target: 5,
    reward: 250,
    unit: 'days',
    defaultTitle: 'Walang mintis',
    description: 'Log every commute for 5 days.',
  ));

  final stepDays = c.dailySteps.entries.where((e) => !e.key.isBefore(dayOf(c.now).subtract(const Duration(days: 14))));
  final avgSteps = stepDays.isEmpty ? 0 : stepDays.map((e) => e.value).reduce((a, b) => a + b) ~/ stepDays.length;
  final stepGoal = avgSteps >= 8000 ? 10000 : 8000;
  quests.add(Quest(
    type: 'steps',
    target: 4,
    reward: 300,
    unit: 'days',
    defaultTitle: stepGoal == 8000 ? '8K era mo na' : '10K club',
    description: 'Reach ${_fmt(stepGoal)} steps on 4 days.',
  )..progress = 0);

  if (quests.length < 3) {
    quests.add(Quest(
      type: 'tag_conditions',
      target: 3,
      reward: 120,
      unit: 'trips',
      defaultTitle: 'Weather reporter',
      description: 'Tag rain, traffic or baha on 3 trips.',
    ));
  }

  for (final q in quests) {
    q.progress = questProgress(q, c, stepGoal: stepGoal);
  }
  return quests.take(3).toList();
}

int questProgress(Quest q, QuestContext c, {int stepGoal = 8000}) {
  final week = c.thisWeek;
  switch (q.type) {
    case 'walk_instead':
      return week.where((t) => t.mode == 'walk').length;
    case 'log_days':
      return week.map((t) => dayOf(t.start)).toSet().length;
    case 'steps':
      final start = weekStart(c.now);
      return c.dailySteps.entries.where((e) => !e.key.isBefore(start) && e.value >= stepGoal).length;
    case 'tag_conditions':
      return week.where((t) => t.tags.isNotEmpty).length;
  }
  return 0;
}

String _fmt(int n) {
  final s = n.toString();
  return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
}
