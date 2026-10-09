/// Things you can spend XP on. Personas only change how Tara talks —
/// the numbers in every answer stay code-computed.
class ShopItem {
  final String id;
  final String name;
  final String blurb;
  final String sample; // what this persona sounds like
  final int cost;
  final String emoji;
  final bool isPersona;

  const ShopItem({
    required this.id,
    required this.name,
    required this.blurb,
    required this.sample,
    required this.cost,
    required this.emoji,
    this.isPersona = true,
  });
}

const kDefaultPersona = 'tito';

const kShopItems = <ShopItem>[
  ShopItem(
    id: 'tito',
    name: 'Tito Tara',
    blurb: 'Chill, may konting hirit.',
    sample: 'Sige, iho. Tara na’t bumiyahe.',
    cost: 0,
    emoji: '🧢',
  ),
  ShopItem(
    id: 'conyo',
    name: 'Conyo Tara',
    blurb: 'Like, commute smart, bestie.',
    sample: 'Bestie, like, super tight na your time, so let’s go na.',
    cost: 400,
    emoji: '💅',
  ),
  ShopItem(
    id: 'coach',
    name: 'Coach Tara',
    blurb: 'Direct, upbeat, no excuses.',
    sample: 'Let’s go! Alis na, kaya mo ’yan!',
    cost: 550,
    emoji: '📣',
  ),
  ShopItem(
    id: 'lola',
    name: 'Lola Tara',
    blurb: 'Warm advice, may baon na care.',
    sample: 'Anak, magdala ka ng payong, ha? Ingat sa biyahe.',
    cost: 650,
    emoji: '👵',
  ),
  ShopItem(
    id: 'streak_shield',
    name: 'Streak shield',
    blurb: 'Protect one missed day.',
    sample: '',
    cost: 300,
    emoji: '🛡️',
    isPersona: false,
  ),
];

ShopItem shopItem(String id) => kShopItems.firstWhere((i) => i.id == id, orElse: () => kShopItems.first);

/// Style instruction injected into the explain prompt for each persona.
const kPersonaStyle = <String, String>{
  'tito': 'You are a friendly Filipino tito. Casual Taglish, a light joke is okay.',
  'conyo': 'You are a conyo Manila friend. Mix English and Tagalog conyo-style ("like", "super", "bestie", "na").',
  'coach': 'You are an upbeat coach. Short, direct, motivating Taglish.',
  'lola': 'You are a caring Filipino lola. Warm, gentle Taglish, call the user "anak".',
};

/// Short tag-on used by template answers when the AI is unavailable.
const kPersonaSignoff = <String, String>{
  'tito': 'Ingat, iho!',
  'conyo': 'Ingat, bestie!',
  'coach': 'Kaya mo ’yan!',
  'lola': 'Ingat ka, anak.',
};

/// Opening line used by template answers so each persona still sounds different.
const kPersonaOpener = <String, String>{
  'tito': '',
  'conyo': 'Okay so, like, ',
  'coach': 'Game plan: ',
  'lola': 'Anak, ',
};
