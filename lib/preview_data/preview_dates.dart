/// Adds [months] while keeping the day valid for the destination month.
DateTime addPreviewMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, date.day.clamp(1, lastDay));
}

/// Returns [day] in a month relative to [anchor], clamped to that month.
DateTime previewMonthDay(DateTime anchor, int monthOffset, int day) {
  final target = DateTime(anchor.year, anchor.month + monthOffset, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, day.clamp(1, lastDay));
}
