import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/substitutions/background.dart';

Substitution _sub({
  String tagEn = '2026-09-01',
  String stunde = '3',
  String? lehrer = 'Müller',
  String? fach = 'Mathe',
  String? raum = '101',
}) => Substitution(
  tag: '01.09.2026',
  tag_en: tagEn,
  stunde: stunde,
  lehrer: lehrer,
  fach: fach,
  raum: raum,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  group('buildSubstitutionsNotification', () {
    test('empty events -> no notification', () {
      expect(buildSubstitutionsNotification([]), isNull);
    });

    test('single added event -> singular title', () {
      final events = [
        SubstitutionChangeEvent(
          type: SubstitutionChangeType.added,
          entryKey: 'Müller|Mathe|3',
          tagEn: '2026-09-01',
          current: _sub(),
        ),
      ];
      final notification = buildSubstitutionsNotification(events);
      expect(notification, isNotNull);
      expect(notification!.title, '1 Änderung im Vertretungsplan');
      expect(notification.body, contains('NEU'));
      expect(notification.body, contains('Mathe'));
    });

    test('multiple events -> plural title, one line per event, sorted', () {
      final events = [
        SubstitutionChangeEvent(
          type: SubstitutionChangeType.removed,
          entryKey: 'Z|Physik|5',
          tagEn: '2026-09-02',
          previous: _sub(tagEn: '2026-09-02', stunde: '5', fach: 'Physik'),
        ),
        SubstitutionChangeEvent(
          type: SubstitutionChangeType.added,
          entryKey: 'A|Deutsch|1',
          tagEn: '2026-09-01',
          current: _sub(tagEn: '2026-09-01', stunde: '1', fach: 'Deutsch'),
        ),
      ];
      final notification = buildSubstitutionsNotification(events);
      expect(notification!.title, '2 Änderungen im Vertretungsplan');
      final lines = notification.body.split('\n');
      expect(lines, hasLength(2));
      // Sorted by tagEn first: 2026-09-01 (Deutsch) before 2026-09-02 (Physik).
      expect(lines[0], contains('Deutsch'));
      expect(lines[1], contains('Physik'));
    });

    test('modified event includes field deltas in the description', () {
      final events = [
        SubstitutionChangeEvent(
          type: SubstitutionChangeType.modified,
          entryKey: 'Müller|Mathe|3',
          tagEn: '2026-09-01',
          previous: _sub(raum: '101'),
          current: _sub(raum: '202'),
          fieldDeltas: const [
            SubstitutionFieldDelta(
              field: 'raum',
              oldValue: '101',
              newValue: '202',
            ),
          ],
        ),
      ];
      final notification = buildSubstitutionsNotification(events);
      expect(notification!.body, contains('GEÄNDERT'));
      expect(notification.body, contains('Raum: 101 → 202'));
    });

    test('removed event describes the previous entry, not a null current', () {
      final events = [
        SubstitutionChangeEvent(
          type: SubstitutionChangeType.removed,
          entryKey: 'Müller|Mathe|3',
          tagEn: '2026-09-01',
          previous: _sub(),
        ),
      ];
      final notification = buildSubstitutionsNotification(events);
      expect(notification!.body, contains('ENTFÄLLT'));
      expect(notification.body, contains('Mathe'));
    });
  });

  group('weekDayGerFromTagEn', () {
    test('converts yyyy-MM-dd to German weekday abbreviation', () {
      // 2026-09-01 is a Tuesday. Delegates straight to intl's DateFormat('E',
      // 'de') — same as the pre-existing weekDayGer() — so this asserts
      // whatever that returns, not a guessed format.
      expect(weekDayGerFromTagEn('2026-09-01'), 'Di');
    });

    test('malformed input is returned unchanged', () {
      expect(weekDayGerFromTagEn('not-a-date'), 'not-a-date');
    });
  });
}
