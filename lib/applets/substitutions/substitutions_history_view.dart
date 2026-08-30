import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

import 'substitutions_view.dart' show formatDate;

class SubstitutionsHistoryScreen extends ConsumerWidget {
  const SubstitutionsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final database = ref.watch(lanisDatabaseProvider);

    final events = account == null
        ? const <SubstitutionChangeEvent>[]
        : loadSubstitutionHistoryEvents(
            database: database,
            accountId: account.localId,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).substitutionsHistory),
      ),
      body: events.isEmpty
          ? _EmptyState(context: context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (context, index) =>
                  _SubstitutionHistoryTile(event: events[index]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final BuildContext context;
  const _EmptyState({required this.context});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 60),
            const SizedBox(height: 16),
            Text(
              l10n.substitutionsHistoryEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.substitutionsHistoryEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubstitutionHistoryTile extends StatelessWidget {
  final SubstitutionChangeEvent event;
  const _SubstitutionHistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sub = event.current ?? event.previous!;

    final (label, color, icon) = switch (event.type) {
      SubstitutionChangeType.added => (
        l10n.substitutionsHistoryStatusAdded,
        Colors.green,
        Icons.add_circle_outline,
      ),
      SubstitutionChangeType.removed => (
        l10n.substitutionsHistoryStatusRemoved,
        Colors.red,
        Icons.remove_circle_outline,
      ),
      SubstitutionChangeType.modified => (
        l10n.substitutionsHistoryStatusModified,
        Colors.orange,
        Icons.edit_outlined,
      ),
    };

    final subtitleParts = [
      if (sub.lehrer != null && sub.lehrer!.isNotEmpty) sub.lehrer,
      if (sub.raum != null && sub.raum!.isNotEmpty) sub.raum,
      if (sub.vertreter != null && sub.vertreter!.isNotEmpty)
        '→ ${sub.vertreter}',
    ].whereType<String>().join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          [
            if (sub.fach != null && sub.fach!.isNotEmpty) sub.fach,
            _formatStunde(sub.stunde),
          ].whereType<String>().join(' · '),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            _formatDay(event.tagEn),
            if (subtitleParts.isNotEmpty) subtitleParts,
          ].join(' — '),
        ),
        trailing: Chip(
          label: Text(label),
          backgroundColor: color.withValues(alpha: 0.15),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
          side: BorderSide.none,
        ),
      ),
    );
  }

  String _formatStunde(String stunde) => 'Std. ${stunde.replaceAll(' - ', '/')}';

  String _formatDay(String tagEn) {
    final parts = tagEn.split('-');
    if (parts.length != 3) return tagEn;
    try {
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return formatDate(date.format('dd.MM.yyyy'));
    } catch (_) {
      return tagEn;
    }
  }
}
