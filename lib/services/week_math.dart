/// Calendar weeks for the challenge, Monday to Sunday. Mirrors the backend's WeekMath so the app and the
/// weekly plan job agree on which week it is.
DateTime _monday(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 1-based challenge week. The calendar week containing [start] is week 1.
int challengeWeek(DateTime start, DateTime today) {
  final weeks = _monday(today).difference(_monday(start)).inDays ~/ 7;
  return weeks < 0 ? 1 : weeks + 1;
}
