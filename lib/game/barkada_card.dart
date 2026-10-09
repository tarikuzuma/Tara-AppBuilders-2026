import 'dart:convert';

import '../data/models.dart';

/// Offline multiplayer: your weekly card travels as a QR code, phone to phone.
/// It carries scores only — never locations or routes.
const _prefix = 'TARA1:';

String encodeCard(Friend f) {
  final payload = jsonEncode({
    'n': f.name,
    'w': f.week,
    'xp': f.xp,
    'st': f.steps,
    'sk': f.streak,
    'lv': f.level,
    't': f.title,
    'a': f.avatar,
    'c': f.color,
  });
  final body = base64Url.encode(utf8.encode(payload));
  return '$_prefix$body.${_checksum(body)}';
}

/// Returns null for anything that isn't a valid Tara card.
Friend? decodeCard(String raw) {
  try {
    if (!raw.startsWith(_prefix)) return null;
    final rest = raw.substring(_prefix.length);
    final dot = rest.lastIndexOf('.');
    if (dot < 0) return null;
    final body = rest.substring(0, dot);
    if (_checksum(body) != rest.substring(dot + 1)) return null;
    final m = jsonDecode(utf8.decode(base64Url.decode(body))) as Map<String, dynamic>;
    final name = (m['n'] as String).trim();
    if (name.isEmpty || name.length > 24) return null;
    return Friend(
      name: name,
      week: m['w'] as String,
      xp: (m['xp'] as num).toInt(),
      steps: (m['st'] as num).toInt(),
      streak: (m['sk'] as num).toInt(),
      level: (m['lv'] as num).toInt(),
      title: m['t'] as String,
      avatar: (m['a'] as String?) ?? '🙂',
      color: ((m['c'] as num?) ?? 0).toInt().clamp(0, 5),
    );
  } catch (_) {
    return null;
  }
}

String _checksum(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(36);
}
