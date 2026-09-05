import 'package:liblanis/liblanis.dart';

/// Whether a pause row should stay hidden because there's no more lesson
/// scheduled after it that day. [pauseEnd] is the pause row's own end
/// time; [rowForStunde] resolves a block's `startStunde` back to its real
/// `TimeTableRow` (for its clock start time).
///
/// An empty [blocksForDay] (no lessons at all that day) always hides the
/// pause -- there is nothing for a break to be "between".
bool shouldHideTrailingPause({
  required SphTimeOfDay pauseEnd,
  required List<MergedLessonBlock> blocksForDay,
  required TimeTableRow? Function(int stunde) rowForStunde,
}) {
  if (blocksForDay.isEmpty) return true;
  return !blocksForDay.any((block) {
    final startRow = rowForStunde(block.startStunde);
    return startRow != null && startRow.startTime >= pauseEnd;
  });
}

/// Whether a subject-less lesson-row (identified by its `stunde`,
/// [TimeTableRow.lessonIndex]) is a genuine free period *sandwiched*
/// between an earlier and a later lesson that day, as opposed to either
/// (a) a continuation row already covered by an earlier multi-hour
/// [MergedLessonBlock], or (b) a free period at the very start or end of
/// the day with nothing to be "between".
///
/// Only the sandwiched case (a) should get a "große Pause" (big-break)
/// visual -- a leading/trailing free period stays invisible, same as
/// today, matching what [shouldHideTrailingPause] already does for the
/// trailing side.
bool isSandwichedFreePeriod({
  required int stunde,
  required List<MergedLessonBlock> blocksForDay,
}) {
  final isCovered = blocksForDay.any(
    (block) => block.startStunde <= stunde && stunde <= block.endStunde,
  );
  if (isCovered) return false;

  final hasLessonBefore = blocksForDay.any((block) => block.endStunde < stunde);
  final hasLessonAfter = blocksForDay.any((block) => block.startStunde > stunde);
  return hasLessonBefore && hasLessonAfter;
}
