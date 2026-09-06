import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/student_timetable_item.dart';

import '../helpers/test_app.dart';

MergedLessonBlock _block({LessonOverlay? overlay}) => MergedLessonBlock(
  stunden: const [3],
  fach: 'Mathe',
  lehrer: 'Müller',
  raum: '101',
  overlay: overlay,
);

Future<void> _pumpBlock(WidgetTester tester, MergedLessonBlock block) async {
  await pumpTestApp(
    tester,
    child: Scaffold(
      body: Stack(
        children: [
          ItemBlock(
            block: block,
            height: 46,
            offset: 0,
            width: 120,
            hOffset: 0,
            settings: const {},
            updateSettings: (_, __) {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  tearDown(LanisClient.reset);

  testWidgets('EVA overlay shows explicit "EVA" text alongside the strikethrough', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(isEva: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('EVA'), findsOneWidget);
  });

  testWidgets('EVA overlay uses pure red (0xFFFF0000) as the block background', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(isEva: true)),
    );

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ItemBlock),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFFF0000));
  });

  testWidgets('no overlay renders normally without crashing or showing EVA', (
    tester,
  ) async {
    await _pumpBlock(tester, _block());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('EVA'), findsNothing);
    expect(find.text('Mathe'), findsOneWidget);
  });

  testWidgets('room-change overlay (non-EVA) does not show EVA text', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(substituteRaum: '202')),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('EVA'), findsNothing);
  });
}
