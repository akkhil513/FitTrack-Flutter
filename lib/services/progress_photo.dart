/// A progress photo as returned by the API. [url] is a short-lived signed link.
class ProgressPhoto {
  const ProgressPhoto({
    required this.key,
    required this.date,
    required this.angle,
    required this.url,
    this.size = 0,
  });

  static const angles = ['front', 'side', 'back'];

  final String key;
  final String date; // yyyy-MM-dd
  final String angle;
  final String url;
  final int size;

  static String angleLabel(String angle) => switch (angle) {
        'front' => 'Front',
        'side' => 'Side',
        'back' => 'Back',
        _ => angle,
      };

  /// Returns null when the map is not a usable photo.
  static ProgressPhoto? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final date = raw['date'];
    final angle = raw['angle'];
    final url = raw['url'];
    if (key is! String || date is! String || angle is! String || url is! String) {
      return null;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return null;
    if (!angles.contains(angle)) return null;
    if (!url.startsWith('https://')) return null;
    final size = raw['size'];
    return ProgressPhoto(
      key: key,
      date: date,
      angle: angle,
      url: url,
      size: size is num ? size.toInt() : 0,
    );
  }

  static List<ProgressPhoto> parseList(Object? raw) {
    if (raw is! List) return [];
    return raw.map(tryFromJson).whereType<ProgressPhoto>().toList();
  }
}

/// All photos taken on one day, in front/side/back order.
class PhotoDay {
  const PhotoDay(this.date, this.photos);
  final String date;
  final List<ProgressPhoto> photos;
}

/// Groups photos by day, newest day first.
List<PhotoDay> groupByDate(List<ProgressPhoto> photos) {
  final byDate = <String, List<ProgressPhoto>>{};
  for (final p in photos) {
    byDate.putIfAbsent(p.date, () => []).add(p);
  }
  final days = byDate.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return [
    for (final e in days)
      PhotoDay(
        e.key,
        e.value
          ..sort((a, b) {
            final byAngle = ProgressPhoto.angles
                .indexOf(a.angle)
                .compareTo(ProgressPhoto.angles.indexOf(b.angle));
            return byAngle != 0 ? byAngle : a.key.compareTo(b.key);
          }),
      ),
  ];
}

/// Puts the older photo first so a comparison always reads "before, after".
List<ProgressPhoto> compareOrder(ProgressPhoto a, ProgressPhoto b) {
  final c = a.date.compareTo(b.date);
  if (c < 0 || (c == 0 && a.key.compareTo(b.key) <= 0)) return [a, b];
  return [b, a];
}
