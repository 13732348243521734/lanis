import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';

import '../../background_service.dart';
import 'package:lanis/l10n/account_type_ui.dart';

Future<void> substitutionsBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit tools,
) async {
  final parser = container.read(substitutionsParserProvider);
  await parser.getHome();

  // Feature 1: getHome() already diffed this fetch against the last-seen
  // snapshot (per day) and persisted the new one. lastChangeEvents is
  // empty on the very first fetch after install/update (no artificial
  // "everything is new" notification) and empty on any fetch that didn't
  // actually change anything -- so unlike before, this task no longer
  // re-sends the full substitution list on every run.
  final notification = buildSubstitutionsNotification(parser.lastChangeEvents);
  if (notification == null) {
    return;
  }

  await tools.sendMessage(
    title: notification.title,
    message: notification.body,
    id: 0,
    importance: Importance.defaultImportance,
    avoidDuplicateSending: true,
  );
}

class SubstitutionsNotificationContent {
  final String title;
  final String body;
  const SubstitutionsNotificationContent({
    required this.title,
    required this.body,
  });
}

/// Builds the notification title/body for a set of diff events, or `null`
/// when there's nothing to notify about. Pure/testable — no I/O, no
/// riverpod, no platform notification plugin.
SubstitutionsNotificationContent? buildSubstitutionsNotification(
  List<SubstitutionChangeEvent> events,
) {
  if (events.isEmpty) {
    return null;
  }

  final sorted = [...events]
    ..sort((a, b) {
      final tagCompare = a.tagEn.compareTo(b.tagEn);
      if (tagCompare != 0) return tagCompare;
      return a.entryKey.compareTo(b.entryKey);
    });

  final body = sorted.map(describeSubstitutionChange).join('\n');
  final title =
      '${events.length} ${events.length == 1 ? 'Änderung' : 'Änderungen'} im Vertretungsplan';

  return SubstitutionsNotificationContent(title: title, body: body);
}

String describeSubstitutionChange(SubstitutionChangeEvent event) {
  final sub = event.current ?? event.previous!;
  final time =
      '${weekDayGerFromTagEn(event.tagEn)} ${sub.stunde.replaceAll(" - ", "/")}';
  final subject = sub.fach ?? '';

  switch (event.type) {
    case SubstitutionChangeType.added:
      final teacher = sub.lehrer ?? '';
      final room = sub.raum ?? '';
      return [time, 'NEU', subject, teacher, room]
          .where((e) => e.isNotEmpty)
          .join(' - ');
    case SubstitutionChangeType.removed:
      final teacher = sub.lehrer ?? '';
      return [time, 'ENTFÄLLT', subject, teacher]
          .where((e) => e.isNotEmpty)
          .join(' - ');
    case SubstitutionChangeType.modified:
      final deltaText = event.fieldDeltas
          .map(
            (d) =>
                '${fieldLabel(d.field)}: ${d.oldValue ?? '–'} → ${d.newValue ?? '–'}',
          )
          .join(', ');
      return [time, 'GEÄNDERT', subject, deltaText]
          .where((e) => e.isNotEmpty)
          .join(' - ');
  }
}

String fieldLabel(String field) {
  switch (field) {
    case 'raum':
      return 'Raum';
    case 'vertreter':
      return 'Vertreter';
    case 'hinweis':
      return 'Hinweis';
    case 'hinweis2':
      return 'Hinweis 2';
    case 'art':
      return 'Art';
    case 'klasse':
      return 'Klasse';
    default:
      return field;
  }
}

/// Like the old `weekDayGer(dateString)`, but keyed off the diff event's
/// `tag_en` (`yyyy-MM-dd`) instead of the display-formatted `dd.MM.yyyy`.
String weekDayGerFromTagEn(String tagEn) {
  final parts = tagEn.split('-');
  if (parts.length != 3) return tagEn;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return tagEn;
  final date = DateTime(year, month, day);
  final germanFormat = DateFormat('E', 'de');
  return germanFormat.format(date);
}
