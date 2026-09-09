import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/timetable/student/student_timetable_item.dart';

void main() {
  group('contrastRatio', () {
    test('black vs white is the maximum, 21:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
    });

    test('a color against itself is 1:1 (no contrast)', () {
      expect(contrastRatio(Colors.red, Colors.red), closeTo(1.0, 0.01));
    });

    test('is symmetric regardless of argument order', () {
      expect(
        contrastRatio(Colors.black, Colors.orange),
        closeTo(contrastRatio(Colors.orange, Colors.black), 0.001),
      );
    });
  });

  group('bestTextColorFor', () {
    test('single light background -> black text', () {
      expect(bestTextColorFor([Colors.white]), Colors.black);
    });

    test('single dark background -> white text', () {
      expect(bestTextColorFor([const Color(0xFF101010)]), Colors.white);
    });

    test(
      'dark subject color striped with light signal color -> white wins '
      '(this is the bug: a fixed "always black" choice would fail here)',
      () {
        // A dark, arbitrary curated/hash-based subject color, striped
        // with a light-ish orange. Black would read fine on the orange
        // stripe but poorly on the dark subject-color stripe -- white
        // has the better *worst-case* contrast across both.
        final darkSubjectColor = const Color(0xFF1A1A2E);
        final lightSignalColor = Colors.orange.shade200;

        final chosen = bestTextColorFor([darkSubjectColor, lightSignalColor]);
        final blackWorst = [
          darkSubjectColor,
          lightSignalColor,
        ].map((c) => contrastRatio(Colors.black, c)).reduce((a, b) => a < b ? a : b);
        final whiteWorst = [
          darkSubjectColor,
          lightSignalColor,
        ].map((c) => contrastRatio(Colors.white, c)).reduce((a, b) => a < b ? a : b);

        expect(chosen, whiteWorst >= blackWorst ? Colors.white : Colors.black);
        expect(chosen, Colors.white);
      },
    );

    test('light subject color striped with dark red -> black wins', () {
      final lightSubjectColor = Colors.yellow.shade100;
      const darkSignalColor = Color(0xFFFF0000); // EVA/cancelled red

      expect(
        bestTextColorFor([lightSubjectColor, darkSignalColor]),
        Colors.black,
      );
    });

    test('ties in worst-case contrast are broken towards black', () {
      // Symmetric case: black's worst case is against veryDark (1:1);
      // white's worst case is against veryLight (1:1) -- a genuine tie.
      // The >= tie-break in bestTextColorFor resolves this to black.
      const veryDark = Color(0xFF000000);
      const veryLight = Color(0xFFFFFFFF);

      expect(bestTextColorFor([veryDark, veryLight]), Colors.black);
    });
  });
}
