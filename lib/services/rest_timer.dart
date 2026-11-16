/// Parses a plan's rest string ("60s", "90 sec", "2 min", "1-2 min") into
/// seconds. Ranges use the lower bound. Falls back to 60s, capped at 10 min.
int parseRestSeconds(String? raw) {
  final text = (raw ?? '').toLowerCase();
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (m == null) return 60;
  final n = double.parse(m.group(1)!);
  final seconds = text.contains('min') ? n * 60 : n;
  if (seconds <= 0) return 60;
  return seconds.round().clamp(10, 600);
}
