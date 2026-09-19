/// Resolves the selected week badge for the student timetable.
///
/// [currentWeekIndex] uses `0` for "all weeks" and `1..n` for
/// [uniqueBadges] entries. Out-of-range / empty badge lists fall back to
/// "all weeks" so UI builds never index an empty list.
({int index, String? badge}) resolveTimetableWeekSelection({
  required int currentWeekIndex,
  required List<String> uniqueBadges,
}) {
  if (uniqueBadges.isEmpty || currentWeekIndex <= 0) {
    return (index: 0, badge: null);
  }
  if (currentWeekIndex > uniqueBadges.length) {
    return (index: 0, badge: null);
  }
  return (
    index: currentWeekIndex,
    badge: uniqueBadges[currentWeekIndex - 1],
  );
}

/// True for Saturday/Sunday. Shared by [initialTimetableWeekIndex] (which
/// week's A/B badge to show) and [mondayOfDisplayedWeek] (which
/// calendar week's dates to show) so both stay in sync -- both must agree
/// on "we're past this week, show next week" or the header dates and the
/// displayed lesson content would visibly disagree.
bool isWeekend(DateTime now) =>
    now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

/// Initial week index from settings / current school week badge.
///
/// On a Saturday or Sunday, the current school week is effectively over,
/// so if an A/B-week rotation exists ([uniqueBadges] has more than one
/// entry), this shows *next* week's badge instead of the one that was
/// active during the week that just ended. [now] is injectable for
/// testing; defaults to the real current time.
int initialTimetableWeekIndex({
  required bool showByWeek,
  required String? weekBadge,
  required List<String> uniqueBadges,
  DateTime? now,
}) {
  if (showByWeek || weekBadge == null || weekBadge.isEmpty) {
    return 0;
  }
  final idx = uniqueBadges.indexOf(weekBadge);
  if (idx < 0) return 0;

  final today = now ?? DateTime.now();
  if (isWeekend(today) && uniqueBadges.length > 1) {
    final nextIdx = (idx + 1) % uniqueBadges.length;
    return nextIdx + 1;
  }
  return idx + 1;
}

/// Monday of the week whose timetable is actually being displayed.
///
/// The timetable always shows the *current* week's template (Mon-Fri),
/// except on a Saturday/Sunday (see [isWeekend]) where it shows next
/// week's A/B badge instead (see [initialTimetableWeekIndex]) -- so the
/// calendar dates used for header labels and for correlating a day's
/// substitutions must advance by 7 days too, or they'd visibly disagree
/// with the lesson content being shown. [now] is injectable for testing;
/// defaults to the real current time.
DateTime mondayOfDisplayedWeek({DateTime? now}) {
  final today = now ?? DateTime.now();
  final thisWeeksMonday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return isWeekend(today)
      ? thisWeeksMonday.add(const Duration(days: 7))
      : thisWeeksMonday;
}

/// True when the timetable has hour rows but no visible day columns after
/// week / hidden-lesson filtering (would crash [DefaultTabController]).
bool isTimetableVisuallyEmpty({
  required bool hoursEmpty,
  required bool daysEmpty,
}) =>
    hoursEmpty || daysEmpty;
