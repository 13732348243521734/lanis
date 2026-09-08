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

/// The DiagonalStripesPainter actually driving one of the CustomPaint
/// widgets in the tree, or null if none is striped (plain ColoredBox
/// background instead).
DiagonalStripesPainter? _findStripesPainter(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  for (final cp in customPaints) {
    if (cp.painter is DiagonalStripesPainter) {
      return cp.painter as DiagonalStripesPainter;
    }
  }
  return null;
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

  testWidgets('EVA overlay stripes with pure red (0xFFFF0000) as one of the two colors', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(isEva: true)),
    );

    final painter = _findStripesPainter(tester);
    expect(painter, isNotNull);
    expect(
      painter!.colorA == const Color(0xFFFF0000) ||
          painter.colorB == const Color(0xFFFF0000),
      isTrue,
    );
  });

  testWidgets('cancelled ("Entfall") overlay shows "Entfällt" text and stripes red', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(isCancelled: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Entfällt'), findsOneWidget);
    // "EVA" must NOT show for a plain cancellation -- different cause,
    // different label, even though both stripe red.
    expect(find.textContaining('EVA'), findsNothing);

    final painter = _findStripesPainter(tester);
    expect(painter, isNotNull);
    expect(
      painter!.colorA == const Color(0xFFFF0000) ||
          painter.colorB == const Color(0xFFFF0000),
      isTrue,
    );
  });

  testWidgets('room-change overlay stripes orange, not red, and shows no EVA/Entfällt text', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(substituteRaum: '202')),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('EVA'), findsNothing);
    expect(find.textContaining('Entfällt'), findsNothing);

    final painter = _findStripesPainter(tester);
    expect(painter, isNotNull);
    expect(
      painter!.colorA == Colors.orange.shade400 ||
          painter.colorB == Colors.orange.shade400,
      isTrue,
    );
    expect(painter.colorA != const Color(0xFFFF0000), isTrue);
    expect(painter.colorB != const Color(0xFFFF0000), isTrue);
  });

  testWidgets('substitute teacher overlay (no room change) also stripes orange', (
    tester,
  ) async {
    await _pumpBlock(
      tester,
      _block(overlay: const LessonOverlay(vertreter: 'Frau Schmidt')),
    );

    expect(tester.takeException(), isNull);
    final painter = _findStripesPainter(tester);
    expect(painter, isNotNull);
    expect(
      painter!.colorA == Colors.orange.shade400 ||
          painter.colorB == Colors.orange.shade400,
      isTrue,
    );
  });

  testWidgets('no overlay renders normally without stripes, EVA, or Entfällt', (
    tester,
  ) async {
    await _pumpBlock(tester, _block());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('EVA'), findsNothing);
    expect(find.textContaining('Entfällt'), findsNothing);
    expect(find.text('Mathe'), findsOneWidget);
    expect(_findStripesPainter(tester), isNull);
  });
}
