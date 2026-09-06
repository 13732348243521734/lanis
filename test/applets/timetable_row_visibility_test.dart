import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/timetable_row_visibility.dart';

MergedLessonBlock _block({required int start, required int end}) =>
    MergedLessonBlock(
      stunden: [for (var s = start; s <= end; s++) s],
      fach: 'Mathe',
    );

TimeTableRow _row({required int stunde, required int startHour}) =>
    TimeTableRow(
      TimeTableRowType.lesson,
      SphTimeOfDay(hour: startHour, minute: 0),
      SphTimeOfDay(hour: startHour, minute: 45),
      '$stunde',
      stunde,
    );

void main() {
  group('shouldHideTrailingPause', () {
    final rows = {
      for (final r in [
        _row(stunde: 1, startHour: 8),
        _row(stunde: 2, startHour: 9),
        _row(stunde: 3, startHour: 10),
        _row(stunde: 4, startHour: 11),
      ])
        r.lessonIndex: r,
    };
    TimeTableRow? rowForStunde(int stunde) => rows[stunde];

    test('no lessons at all that day -> hidden', () {
      expect(
        shouldHideTrailingPause(
          pauseEnd: const SphTimeOfDay(hour: 9, minute: 45),
          blocksForDay: const [],
          rowForStunde: rowForStunde,
        ),
        isTrue,
      );
    });

    test('a lesson starts after the pause -> not hidden', () {
      // Pause after period 2 (ends 9:45), period 3 starts 10:00 -- a real
      // lesson follows, so the pause should stay visible.
      expect(
        shouldHideTrailingPause(
          pauseEnd: const SphTimeOfDay(hour: 9, minute: 45),
          blocksForDay: [_block(start: 1, end: 2), _block(start: 3, end: 3)],
          rowForStunde: rowForStunde,
        ),
        isFalse,
      );
    });

    test('pause after the last lesson of the day -> hidden', () {
      // Only lessons in periods 1-2; a pause after period 2 has nothing
      // left afterwards.
      expect(
        shouldHideTrailingPause(
          pauseEnd: const SphTimeOfDay(hour: 9, minute: 45),
          blocksForDay: [_block(start: 1, end: 2)],
          rowForStunde: rowForStunde,
        ),
        isTrue,
      );
    });

    test('pause before the only lesson of the day -> not hidden', () {
      // Lesson starts in period 3; a pause ending before that (e.g. after
      // period 1) still has something scheduled afterwards.
      expect(
        shouldHideTrailingPause(
          pauseEnd: const SphTimeOfDay(hour: 8, minute: 45),
          blocksForDay: [_block(start: 3, end: 3)],
          rowForStunde: rowForStunde,
        ),
        isFalse,
      );
    });
  });

  group('isSandwichedFreePeriod', () {
    test('free period with a lesson before and after -> sandwiched', () {
      expect(
        isSandwichedFreePeriod(
          stunde: 3,
          blocksForDay: [_block(start: 1, end: 2), _block(start: 4, end: 4)],
        ),
        isTrue,
      );
    });

    test('free period only before the first lesson -> not sandwiched', () {
      expect(
        isSandwichedFreePeriod(
          stunde: 1,
          blocksForDay: [_block(start: 3, end: 4)],
        ),
        isFalse,
      );
    });

    test('free period only after the last lesson -> not sandwiched', () {
      expect(
        isSandwichedFreePeriod(
          stunde: 5,
          blocksForDay: [_block(start: 1, end: 2)],
        ),
        isFalse,
      );
    });

    test('row covered by an ongoing multi-hour block -> not a free period', () {
      // Period 4 is the second half of a 3-4 double lesson -- it must not
      // be mistaken for a free period even though no block *starts* there.
      expect(
        isSandwichedFreePeriod(
          stunde: 4,
          blocksForDay: [_block(start: 3, end: 4), _block(start: 6, end: 6)],
        ),
        isFalse,
      );
    });

    test('no lessons at all that day -> never sandwiched', () {
      expect(
        isSandwichedFreePeriod(stunde: 3, blocksForDay: const []),
        isFalse,
      );
    });

    test('multiple free periods in a row are each independently sandwiched', () {
      final blocksForDay = [_block(start: 1, end: 2), _block(start: 5, end: 5)];
      expect(isSandwichedFreePeriod(stunde: 3, blocksForDay: blocksForDay), isTrue);
      expect(isSandwichedFreePeriod(stunde: 4, blocksForDay: blocksForDay), isTrue);
    });
  });
  group('isBreakRow', () {
    TimeTableRow pauseRow({required int startHour, int startMinute = 0, required int endHour, int endMinute = 0}) =>
        TimeTableRow(
          TimeTableRowType.pause,
          SphTimeOfDay(hour: startHour, minute: startMinute),
          SphTimeOfDay(hour: endHour, minute: endMinute),
          'Pause',
          -1,
        );

    TimeTableRow? rowForStundeAmong(List<TimeTableRow> rows, int stunde) {
      for (final r in rows) {
        if (r.type == TimeTableRowType.lesson && r.lessonIndex == stunde) return r;
      }
      return null;
    }

    test('a normal, non-hidden pause is a break row', () {
      final lessonRows = [
        _row(stunde: 1, startHour: 8),
        _row(stunde: 2, startHour: 10),
      ];
      final pause = pauseRow(startHour: 8, startMinute: 45, endHour: 10);
      expect(
        isBreakRow(
          row: pause,
          blocksForDay: [_block(start: 1, end: 1), _block(start: 2, end: 2)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isTrue,
      );
    });

    test('a pause inside a spanning double-period block is not a break row', () {
      final lessonRows = [
        _row(stunde: 3, startHour: 10),
        _row(stunde: 4, startHour: 11),
      ];
      final pause = pauseRow(startHour: 10, startMinute: 45, endHour: 11);
      expect(
        isBreakRow(
          row: pause,
          blocksForDay: [_block(start: 3, end: 4)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isFalse,
      );
    });

    test('a trailing pause with nothing scheduled afterwards is not a break row', () {
      final lessonRows = [_row(stunde: 1, startHour: 8)];
      final pause = pauseRow(startHour: 8, startMinute: 45, endHour: 9);
      expect(
        isBreakRow(
          row: pause,
          blocksForDay: [_block(start: 1, end: 1)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isFalse,
      );
    });

    test('a lesson row with no block that is sandwiched is a break row', () {
      final lessonRows = [
        _row(stunde: 1, startHour: 8),
        _row(stunde: 2, startHour: 9),
        _row(stunde: 3, startHour: 10),
      ];
      expect(
        isBreakRow(
          row: lessonRows[1], // stunde 2, free
          blocksForDay: [_block(start: 1, end: 1), _block(start: 3, end: 3)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isTrue,
      );
    });

    test('a lesson row that starts a real block is not a break row', () {
      final lessonRows = [_row(stunde: 1, startHour: 8)];
      expect(
        isBreakRow(
          row: lessonRows[0],
          blocksForDay: [_block(start: 1, end: 1)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isFalse,
      );
    });

    test('a lesson row that is a continuation of an ongoing block is not a break row', () {
      final lessonRows = [
        _row(stunde: 3, startHour: 10),
        _row(stunde: 4, startHour: 11),
      ];
      expect(
        isBreakRow(
          row: lessonRows[1], // stunde 4, covered by the 3-4 block
          blocksForDay: [_block(start: 3, end: 4)],
          rowForStunde: (s) => rowForStundeAmong(lessonRows, s),
        ),
        isFalse,
      );
    });

    test('two consecutive break rows (pause then free period) both report true, enabling merging', () {
      final lessonRows = [
        _row(stunde: 1, startHour: 8),
        _row(stunde: 2, startHour: 10), // free period, sandwiched
        _row(stunde: 3, startHour: 11),
      ];
      final pause = pauseRow(startHour: 8, startMinute: 45, endHour: 10);
      final blocksForDay = [_block(start: 1, end: 1), _block(start: 3, end: 3)];
      TimeTableRow? lookup(int s) => rowForStundeAmong(lessonRows, s);

      expect(isBreakRow(row: pause, blocksForDay: blocksForDay, rowForStunde: lookup), isTrue);
      expect(isBreakRow(row: lessonRows[1], blocksForDay: blocksForDay, rowForStunde: lookup), isTrue);
    });
  });
}
