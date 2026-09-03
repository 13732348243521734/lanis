import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A curated color for a subject, together with a couple of alternatives
/// that can be offered as a quick-pick next to the free-form color picker.
class SubjectColorEntry {
  final Color primary;
  final List<Color> alternatives;

  const SubjectColorEntry({required this.primary, required this.alternatives});
}

/// Loads `assets/subject_colors.json` and allows looking up a curated color
/// for a subject by matching its *normalized* name against a list of known
/// aliases (full names and common abbreviations).
///
/// Normalization strips everything that is not a letter and lowercases the
/// rest, so "bio", "BIOLOGIE" and "Bio!" all resolve to the same lookup key.
/// This only works for an exact match after stripping punctuation/case —
/// it does *not* extract a "core" subject token from a longer combined
/// string. Names like "Bio (GK)" or "Biologie - S2" will normalize to
/// "biogk"/"biologies" respectively, which won't match the "bio"/"biologie"
/// aliases, and [lookup] falls through to the caller's own fallback (see
/// `TimeTableHelper.getColorForLesson`, which falls back to a hash-based
/// color). In practice `TimetableSubject.name` is the bare, portal-parsed
/// subject abbreviation (course/group qualifiers are parsed into a
/// separate `badge` field upstream), so this is expected to match the
/// common case; schools whose Stundenplan display settings embed course
/// info directly into the subject name may see more fallback colors.
class SubjectColors {
  SubjectColors._();

  static Map<String, SubjectColorEntry>? _aliasLookup;

  static final RegExp _letterPattern = RegExp(r'[a-zA-ZäöüÄÖÜß]');

  /// Removes everything that is not a letter and lowercases the input.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (_letterPattern.hasMatch(char)) {
        buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString();
  }

  /// Loads and parses the JSON asset. Safe to call multiple times; only
  /// loads once. Should be awaited once during app startup (see main.dart)
  /// so that [lookup] can be used synchronously afterwards.
  static Future<void> ensureLoaded() async {
    if (_aliasLookup != null) return;

    final Map<String, SubjectColorEntry> lookupTable = {};

    try {
      final raw = await rootBundle.loadString('assets/subject_colors.json');
      final List<dynamic> data = json.decode(raw) as List<dynamic>;

      for (final rawEntry in data) {
        final entry = rawEntry as Map<String, dynamic>;
        final primary = _parseHex(entry['primary'] as String);
        final alternatives = ((entry['alternatives'] as List<dynamic>?) ?? [])
            .map((hex) => _parseHex(hex as String))
            .toList();
        final colorEntry = SubjectColorEntry(
          primary: primary,
          alternatives: alternatives,
        );

        final aliases = (entry['aliases'] as List<dynamic>? ?? []);
        for (final alias in aliases) {
          lookupTable[normalize(alias as String)] = colorEntry;
        }
      }
    } catch (_) {
      // If the asset can't be loaded/parsed for some reason, we simply end
      // up with an empty table and callers fall back to the hash-based
      // random color, so the app keeps working either way.
    }

    _aliasLookup = lookupTable;
  }

  static Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  /// Looks up a curated color entry for [subjectName]. Returns null if the
  /// table hasn't been loaded yet, or no alias matches the normalized name.
  static SubjectColorEntry? lookup(String subjectName) {
    final table = _aliasLookup;
    if (table == null || table.isEmpty) return null;
    return table[normalize(subjectName)];
  }
}
