import '../data/models.dart';

/// XP rules. All scoring is code; the AI never awards XP.
const kXpPerTrip = 50;
const kXpPerTaggedTrip = 20;
const kXpPerWalkKm = 20;
const kXpPer1000Steps = 10;
const kXpStreakBonus = 100; // every 7 consecutive days
const kXpPerLevel = 500;

class XpAward {
  final int amount;
  final String reason;
  const XpAward(this.amount, this.reason);
}

/// XP earned for saving one trip.
List<XpAward> xpForTrip(Trip t) {
  final awards = <XpAward>[const XpAward(kXpPerTrip, 'Trip logged')];
  if (t.tags.isNotEmpty) awards.add(const XpAward(kXpPerTaggedTrip, 'Condition tag'));
  if (t.mode == 'walk' && (t.km ?? 0) >= 1) {
    awards.add(XpAward((t.km!.floor()) * kXpPerWalkKm, 'Walking km'));
  }
  return awards;
}

int xpForSteps(int steps) => (steps ~/ 1000) * kXpPer1000Steps;

/// Level comes from lifetime earned XP (spending in the shop never lowers it).
int levelFor(int lifetimeXp) => lifetimeXp ~/ kXpPerLevel + 1;
int xpForLevel(int level) => (level - 1) * kXpPerLevel;

const _titles = <int, String>{
  1: 'Biyahe Rookie',
  4: 'Lakbay Local',
  8: 'Campus Navigator',
  12: 'Street Smart',
  16: 'Hari ng Kalsada',
};

String titleFor(int level) {
  var title = _titles[1]!;
  for (final e in _titles.entries) {
    if (level >= e.key) title = e.value;
  }
  return title;
}

String? nextTitle(int level) {
  for (final e in _titles.entries) {
    if (e.key > level) return e.value;
  }
  return null;
}

class XpSummary {
  final int lifetime;
  final int balance;
  final int level;
  final String title;
  final int intoLevel;
  final int levelSpan;

  XpSummary(this.lifetime, this.balance)
      : level = levelFor(lifetime),
        title = titleFor(levelFor(lifetime)),
        intoLevel = lifetime - xpForLevel(levelFor(lifetime)),
        levelSpan = kXpPerLevel;

  int get nextLevelAt => xpForLevel(level + 1);
  int get toNext => nextLevelAt - lifetime;
  double get progress => intoLevel / levelSpan;
}

XpSummary summarize(List<XpEvent> events) {
  var lifetime = 0, balance = 0;
  for (final e in events) {
    balance += e.amount;
    if (e.amount > 0) lifetime += e.amount;
  }
  return XpSummary(lifetime, balance);
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Consecutive days (ending today, or yesterday if nothing yet today) with at
/// least one trip. Each owned streak shield forgives one missed day.
int streakDays(List<Trip> trips, DateTime today, {int shields = 0}) {
  final days = trips.map((t) => dayOf(t.start)).toSet();
  var cursor = dayOf(today);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  var shieldsLeft = shields;
  while (true) {
    if (days.contains(cursor)) {
      streak++;
    } else if (shieldsLeft > 0 && streak > 0) {
      shieldsLeft--;
    } else {
      break;
    }
    cursor = cursor.subtract(const Duration(days: 1));
    if (streak > 365) break;
  }
  return streak;
}

/// ISO-8601 week key, e.g. "2026-W41".
String isoWeek(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final ordinal = thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays + 1;
  final week = (ordinal - 1) ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

DateTime weekStart(DateTime d) => dayOf(d).subtract(Duration(days: d.weekday - 1));
