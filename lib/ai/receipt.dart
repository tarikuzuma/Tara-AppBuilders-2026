/// Parses text the vision model read off a ride receipt / app screenshot.
/// The model only transcribes; code extracts the numbers.
class ReceiptFields {
  double? fare;
  String? pickup;
  String? dropoff;
  int? minutes;
  bool get isEmpty => fare == null && pickup == null && dropoff == null && minutes == null;
}

ReceiptFields parseReceipt(String text) {
  final f = ReceiptFields();
  final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  // Fare: prefer amounts on a "total/paid/fare" line, else the largest ₱/PHP amount.
  final money = RegExp(r'(?:₱|php|p)\s?(\d{1,5}(?:[.,]\d{2})?)', caseSensitive: false);
  double? best;
  for (final l in lines) {
    final m = money.firstMatch(l);
    if (m == null) continue;
    final v = double.parse(m.group(1)!.replaceAll(',', '.'));
    if (RegExp(r'(total|paid|amount|bayad|charged)', caseSensitive: false).hasMatch(l)) {
      f.fare = v;
      break;
    }
    if (best == null || v > best) best = v;
  }
  f.fare ??= best;

  String? after(RegExp label) {
    for (var i = 0; i < lines.length; i++) {
      final m = label.firstMatch(lines[i]);
      if (m == null) continue;
      final rest = lines[i]
          .substring(m.end)
          .replaceFirst(RegExp(r'^\s*(location|point|address)?\s*[:\-–]?\s*', caseSensitive: false), '')
          .trim();
      if (rest.isNotEmpty) return rest;
      if (i + 1 < lines.length) return lines[i + 1];
    }
    return null;
  }

  f.pickup = after(RegExp(r'(pick[\s-]?up|from|origin)', caseSensitive: false));
  f.dropoff = after(RegExp(r'(drop[\s-]?off|destination|to:)', caseSensitive: false));

  final mins = RegExp(r'(\d{1,3})\s*(?:min|mins|minutes)\b', caseSensitive: false).firstMatch(text);
  if (mins != null) f.minutes = int.parse(mins.group(1)!);
  return f;
}
