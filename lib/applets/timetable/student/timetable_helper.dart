import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/random_color.dart';
import 'package:lanis/utils/subject_colors.dart';

class TimeTableHelper {
  static Color getColorForLesson(dynamic settings, lesson) {
    // 1. Did the user pick a custom color for this lesson themselves?
    final colors = settings is Map ? settings['lesson-colors'] : null;
    if (colors is Map) {
      final stored = colors[lesson.id.split('-')[0]];
      if (stored is String && stored.isNotEmpty) {
        return Color(int.parse(stored, radix: 16));
      }
    }

    // 2. Does the (normalized) subject name match our curated color table?
    final curated = SubjectColors.lookup(lesson.name!);
    if (curated != null) {
      return curated.primary;
    }

    // 3. Last resort: deterministic hash-based color.
    return RandomColor.bySeed(lesson.name!).primary;
  }

  static List<List<T>> mergeByIndices<T>(
    List<List<T>> list1,
    List<List<T>>? list2,
  ) {
    final int maxLength = list1.length > (list2?.length ?? 0)
        ? list1.length
        : (list2?.length ?? 0);

    final List<List<T>> result = List.generate(maxLength, (index) {
      List<T> combined = [];
      if (index < list1.length) combined.addAll(list1[index]);

      if (list2 != null && index < list2.length) {
        combined.addAll(list2[index]);
      }
      return combined;
    });

    return result;
  }

  static List<List<TimetableSubject>>? getCustomLessons(
    Map<String, dynamic> settings,
  ) {
    final raw = settings['custom-lessons'];
    // Defaults use an empty list; treat that like "unset" so callers can use
    // `customLessons?[day]` without indexing an empty list.
    if (raw == null || raw is! List || raw.isEmpty) return null;
    return raw
        .map(
          (e) => (e as List).map((item) {
            if (item.runtimeType == TimetableSubject) {
              return item as TimetableSubject;
            }
            return TimetableSubject.fromJson(item);
          }).toList(),
        )
        .toList();
  }
}
