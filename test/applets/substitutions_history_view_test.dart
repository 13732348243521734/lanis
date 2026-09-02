import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/substitutions/substitutions_history_view.dart';

import '../helpers/test_app.dart';

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

Future<void> _pumpTile(WidgetTester tester, SubstitutionChangeEvent event) async {
  await pumpTestApp(
    tester,
    child: Scaffold(body: SubstitutionHistoryTile(event: event)),
  );
}

void main() {
  tearDown(LanisClient.reset);

  testWidgets('modified entry shows the persisted field delta', (tester) async {
    await _pumpTile(
      tester,
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
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Raum: 101 → 202'), findsOneWidget);
  });

  testWidgets('modified entry without deltas does not crash and shows no delta line', (
    tester,
  ) async {
    await _pumpTile(
      tester,
      SubstitutionChangeEvent(
        type: SubstitutionChangeType.modified,
        entryKey: 'Müller|Mathe|3',
        tagEn: '2026-09-01',
        previous: _sub(raum: '101'),
        current: _sub(raum: '202'),
        // fieldDeltas intentionally empty -- e.g. an entry modified before
        // this feature shipped, migrated without a persisted delta.
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('added entry does not render a delta line even if fieldDeltas were passed', (
    tester,
  ) async {
    await _pumpTile(
      tester,
      SubstitutionChangeEvent(
        type: SubstitutionChangeType.added,
        entryKey: 'Müller|Mathe|3',
        tagEn: '2026-09-01',
        current: _sub(),
        fieldDeltas: const [
          SubstitutionFieldDelta(
            field: 'raum',
            oldValue: '101',
            newValue: '202',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    // Delta line is gated on event.type == modified, not just non-empty
    // fieldDeltas -- an added entry has no meaningful "previous" state.
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('removed entry renders using the previous snapshot, not a null current', (
    tester,
  ) async {
    await _pumpTile(
      tester,
      SubstitutionChangeEvent(
        type: SubstitutionChangeType.removed,
        entryKey: 'Müller|Mathe|3',
        tagEn: '2026-09-01',
        previous: _sub(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Mathe · Std. 3'), findsOneWidget);
  });
}
