import 'supplement_reminder.dart';

/// A common supplement with the time it is usually taken. General guidance only, not medical advice.
class SupplementSuggestion {
  const SupplementSuggestion(this.name, this.hour, this.minute, this.hint);

  final String name;
  final int hour;
  final int minute;
  final String hint;
}

const supplementCatalog = <SupplementSuggestion>[
  SupplementSuggestion('Vitamin D3', 8, 0, 'Usually taken with a meal that has some fat'),
  SupplementSuggestion('Omega-3', 13, 0, 'Usually taken with a meal'),
  SupplementSuggestion('Multivitamin', 8, 0, 'Usually taken with breakfast'),
  SupplementSuggestion('Creatine', 9, 0, 'Daily; the time of day matters little'),
  SupplementSuggestion('Magnesium', 21, 30, 'Often taken in the evening'),
  SupplementSuggestion('Zinc', 18, 0, 'Usually taken with food'),
  SupplementSuggestion('Vitamin C', 8, 0, 'Any time, often with a meal'),
  SupplementSuggestion('Vitamin B12', 8, 0, 'Often taken in the morning'),
  SupplementSuggestion('Probiotic', 7, 30, 'Often taken in the morning'),
  SupplementSuggestion('Whey protein', 14, 0, 'Often taken after training'),
];

/// The first catalog entry named anywhere in [text] (case-insensitive), or null.
SupplementSuggestion? catalogMatch(String text) {
  final lower = text.toLowerCase();
  for (final s in supplementCatalog) {
    if (lower.contains(s.name.toLowerCase())) return s;
  }
  return null;
}

/// Adds [name] to a comma-separated list, skipping duplicates and respecting the length limit.
String addSupplementName(String current, String name) {
  final trimmed = current.trim();
  if (trimmed.isEmpty) return name;
  final parts = trimmed
      .split(',')
      .map((p) => p.trim().toLowerCase())
      .where((p) => p.isNotEmpty);
  if (parts.contains(name.toLowerCase())) return trimmed;
  final joined = '${trimmed.replaceAll(RegExp(r',\s*$'), '')}, $name';
  return joined.length > SupplementReminder.maxLabelLength ? trimmed : joined;
}
