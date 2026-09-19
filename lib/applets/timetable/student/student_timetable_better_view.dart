import 'dart:async';

import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/student_timetable_item.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

final double itemHeight = 46;
final double headerHeight = 40;
final double hourWidth = 70;
final double pauseHeight = 18;

class StudentTimetableBetterView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const StudentTimetableBetterView({super.key, this.openDrawerCb});

  @override
  ConsumerState<StudentTimetableBetterView> createState() =>
      _StudentTimetableBetterViewState();
}

class _StudentTimetableBetterViewState
    extends ConsumerState<StudentTimetableBetterView> {
  List<TimetableDay> getSelectedPlan(
    TimeTable data,
    TimeTableType selectedType,
    Map<String, dynamic> settings,
  ) {
    List<List<TimetableSubject>>? customLessons =
        TimeTableHelper.getCustomLessons(settings);
    if (selectedType == TimeTableType.own && data.planForOwn != null) {
      return TimeTableHelper.mergeByIndices(data.planForOwn!, customLessons);
    }
    final planForAll = data.planForAll;
    if (planForAll == null) {
      return const [];
    }
    return TimeTableHelper.mergeByIndices(planForAll, customLessons);
  }

  int currentWeekIndex = -1;

  /// Weeks relative to [mondayOfDisplayedWeek] currently being shown
  /// (feature plan 7.5): `0` is the normal live view, negative values
  /// browse backwards through `timetable_history`. Forward navigation
  /// beyond `0` isn't offered yet -- that needs the `detail_klasse`
  /// redirect (plan 5.3), which doesn't exist yet, so `0` is also the
  /// upper bound here.
  int weekOffset = 0;

  DateTime _displayedWeekMonday() =>
      mondayOfDisplayedWeek().add(Duration(days: 7 * weekOffset));

  @override
  void initState() {
    super.initState();
    // Feature 2 (Stundenplan-Overlay): kick off a substitution fetch once
    // if we don't already have data -- the substitutions parser is a
    // keepAlive singleton shared with the Vertretungsplan screen, so this
    // is a no-op if the user already visited it this session. Substitution
    // overlay is a "nice to have" secondary data source for this screen:
    // if it's still loading/errors, TimeTableView just renders without
    // overlay (see the StreamBuilder around it in build()), never blocks
    // or fails the main timetable render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final substitutionsParser = ref.read(substitutionsParserProvider);
      if (substitutionsParser.latestResponse?.status != FetcherStatus.done) {
        substitutionsParser.fetchData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(timeTableDefinition.label(context)),
          leading: widget.openDrawerCb != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.openDrawerCb!(),
                )
              : null,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final accountType = session.accountTypeOrNull ??
        ref.read(activeAccountProvider)?.accountType ??
        AccountType.student;
    return CombinedAppletBuilder<TimeTable>(
      parser: ref.watch(timetableParserProvider),
      phpUrl: timeTableDefinition.appletPhpUrl,
      settingsDefaults: timeTableDefinition.settingsDefaults,
      accountType: accountType,
      loadingAppBar: AppBar(
        title: Text(timeTableDefinition.label(context)),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
      ),
      builder:
          (
            BuildContext context,
            TimeTable timetable,
            _,
            Map<String, dynamic> settings,
            updateSettings,
            Future<void> Function()? refresh,
          ) {
            // Feature 2.5 (Stundenplanhistorie, plan 7.5): while browsing a
            // past week (weekOffset < 0), the plan shown is a stored
            // snapshot from timetable_history rather than the live fetch.
            // `historicalTimetable` is `null` both while weekOffset == 0
            // (not applicable) and when no snapshot exists that far back
            // yet -- the two are told apart below via `weekOffset != 0`.
            final database = ref.watch(lanisDatabaseProvider);
            final account = ref.watch(activeAccountProvider);
            final weekMonday = _displayedWeekMonday();
            final TimeTable? historicalTimetable =
                weekOffset == 0 || account == null
                ? null
                : loadTimetableForWeek(
                    database: database,
                    accountId: account.localId,
                    weekMonday: weekMonday,
                  );
            final TimeTable displayTimetable = weekOffset == 0
                ? timetable
                : (historicalTimetable ??
                      TimeTable(
                        planForAll: const [],
                        planForOwn: null,
                        hours: const [],
                        weekBadge: null,
                      ));

            final DateTime? earliestHistoryWeek = account == null
                ? null
                : earliestTimetableHistoryWeek(
                    database: database,
                    accountId: account.localId,
                  );
            // Enabled as long as there's a stored week strictly before the
            // one currently shown -- once weekMonday reaches the earliest
            // row on file, going further back would just hit
            // viewingHistoryWithoutData (nothing to fall back to before
            // that point, feature plan 7.5: "rückwärts unbegrenzt, soweit
            // Historie vorhanden").
            final navigation = resolveTimetableWeekNavigation(
              weekOffset: weekOffset,
              weekMonday: weekMonday,
              earliestHistoryWeek: earliestHistoryWeek,
              hasHistoricalData: historicalTimetable != null,
            );
            final bool canGoBack = navigation.canGoBack;
            final bool canGoForward = navigation.canGoForward;
            final bool viewingHistoryWithoutData =
                navigation.viewingHistoryWithoutData;

            TimeTableType selectedType =
                settings['student-selected-type'] == 'TimeTableType.own'
                ? TimeTableType.own
                : TimeTableType.all;
            bool showByWeek = settings['student-selected-week'] == true;
            List<TimetableDay> selectedPlan = getSelectedPlan(
              displayTimetable,
              selectedType,
              settings,
            );
            final List<String> uniqueBadges = selectedPlan
                .expand((innerList) => innerList.map((e) => e.badge))
                .whereType<String>()
                .toSet()
                .toList();

            if (currentWeekIndex == -1) {
              currentWeekIndex = initialTimetableWeekIndex(
                showByWeek: showByWeek,
                weekBadge: displayTimetable.weekBadge,
                uniqueBadges: uniqueBadges,
              );
            }
            final weekSelection = resolveTimetableWeekSelection(
              currentWeekIndex: currentWeekIndex,
              uniqueBadges: uniqueBadges,
            );
            currentWeekIndex = weekSelection.index;

            TimeTableData data = TimeTableData(
              selectedPlan,
              displayTimetable,
              settings,
              weekSelection.badge,
            );

            final appBar = AppBar(
              title: Text(timeTableDefinition.label(context)),
              leading: widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
              actions: data.hours.isEmpty && !viewingHistoryWithoutData
                  ? null
                  : [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            // Feature 2.5 (Stundenplanhistorie, plan 7.5):
                            // Prev/Next week navigation. Forward is capped
                            // at the live week (canGoForward) -- browsing
                            // further into the future needs the
                            // `detail_klasse` redirect (plan 5.3), not
                            // built yet.
                            IconButton(
                              tooltip: AppLocalizations.of(
                                context,
                              ).timetablePreviousWeek,
                              onPressed: canGoBack
                                  ? () => setState(() => weekOffset -= 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.of(
                                context,
                              ).timetableNextWeek,
                              onPressed: canGoForward
                                  ? () => setState(() => weekOffset += 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                            if (uniqueBadges.isNotEmpty &&
                                displayTimetable.weekBadge != null)
                              TextButton(
                                onPressed: () {
                                  currentWeekIndex =
                                      (currentWeekIndex + 1) %
                                      (uniqueBadges.length + 1);
                                  updateSettings(
                                    'student-selected-week',
                                    currentWeekIndex == 0,
                                  );
                                },
                                child: Text(
                                  (currentWeekIndex < 1)
                                      ? AppLocalizations.of(
                                          context,
                                        ).timetableAllWeeks
                                      : AppLocalizations.of(
                                          context,
                                        ).timetableWeek(
                                          uniqueBadges[currentWeekIndex - 1],
                                        ),
                                ),
                              ),
                            IconButton(
                              onPressed: () => updateSettings(
                                'single-day',
                                !(settings['single-day'] ?? false),
                              ),
                              icon: (settings['single-day'] ?? false)
                                  ? Icon(Icons.calendar_today)
                                  : Icon(Icons.calendar_today_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
            );

            if (viewingHistoryWithoutData ||
                isTimetableVisuallyEmpty(
                  hoursEmpty: data.hours.isEmpty,
                  daysEmpty: data.timetableDays.isEmpty,
                )) {
              return Scaffold(
                appBar: appBar,
                body: RefreshIndicator(
                  notificationPredicate: refresh != null
                      ? (_) => true
                      : (_) => false,
                  onRefresh: refresh ?? () async {},
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(),
                            const Icon(Icons.sentiment_dissatisfied, size: 60),
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Text(
                                    viewingHistoryWithoutData
                                        ? AppLocalizations.of(
                                            context,
                                          ).timetableHistoryUnavailableTitle
                                        : AppLocalizations.of(
                                            context,
                                          ).noEntries,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (viewingHistoryWithoutData) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).timetableHistoryUnavailableSubtitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => weekOffset = 0),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).timetableBackToCurrentWeek,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final substitutionsParser = ref.watch(substitutionsParserProvider);

            return Scaffold(
              appBar: appBar,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: StreamBuilder<FetcherResponse<SubstitutionPlan>>(
                  stream: substitutionsParser.stream,
                  initialData: substitutionsParser.latestResponse,
                  builder: (context, subSnapshot) {
                    final substitutionPlan =
                        subSnapshot.data?.status == FetcherStatus.done
                        ? subSnapshot.data?.content
                        : null;

                    final now = DateTime.now();
                    final todayDateOnly = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    );

                    // Feature 2 + 7.5: for the live/current week's days
                    // that haven't happened yet, only the live fetch makes
                    // sense (nothing to reconstruct from history). For any
                    // past day -- whether just an already-passed day in
                    // the current week (which the portal's own tabs stop
                    // exposing once it's over) or a whole past week being
                    // browsed via weekOffset -- prefer the live plan if it
                    // still happens to have that date, otherwise fall back
                    // to substitution_history.
                    List<Substitution> substitutionsForDate(DateTime date) {
                      final dateOnly = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final dateStr = date.format('dd.MM.yyyy');
                      final live =
                          substitutionPlan?.days
                              .where((d) => d.parsedDate == dateStr)
                              .expand((d) => d.substitutions)
                              .toList() ??
                          const <Substitution>[];

                      final isPastDate = dateOnly.isBefore(todayDateOnly);
                      if (weekOffset == 0 && !isPastDate) {
                        return live;
                      }
                      if (live.isNotEmpty) return live;
                      if (account == null) return const <Substitution>[];
                      final historical = loadSubstitutionDayForDisplay(
                        database: database,
                        accountId: account.localId,
                        tagEn: DateFormat('yyyy-MM-dd').format(date),
                      );
                      return historical?.substitutions ??
                          const <Substitution>[];
                    }

                    return TimeTableView(
                      data: data,
                      timetable: displayTimetable,
                      weekMonday: weekMonday,
                      settings: settings,
                      updateSettings: updateSettings,
                      refresh: refresh,
                      substitutionsForDate: substitutionsForDate,
                    );
                  },
                ),
              ),
              floatingActionButton: displayTimetable.planForOwn != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FloatingActionButton(
                          heroTag: "toggle",
                          tooltip: selectedType == TimeTableType.all
                              ? AppLocalizations.of(
                                  context,
                                ).timetableSwitchToPersonal
                              : AppLocalizations.of(
                                  context,
                                ).timetableSwitchToClass,
                          onPressed: () {
                            updateSettings(
                              'student-selected-type',
                              selectedType == TimeTableType.all
                                  ? 'TimeTableType.own'
                                  : 'TimeTableType.all',
                            );
                          },
                          child: Icon(
                            selectedType == TimeTableType.all
                                ? Icons.person
                                : Icons.people,
                          ),
                        ),
                      ],
                    )
                  : null,
            );
          },
    );
  }
}

class TimeTableView extends StatelessWidget {
  final TimeTableData data;
  final TimeTable timetable;
  final Map<String, dynamic> settings;
  final Function updateSettings;
  final Future<void> Function()? refresh;

  /// Monday of the week actually being displayed. Normally
  /// [mondayOfDisplayedWeek], but a different (earlier) Monday while
  /// browsing timetable history via [weekOffset] in the parent state.
  final DateTime weekMonday;

  /// Feature 2 (Stundenplan-Overlay) + 7.5 (Historie): resolves the
  /// substitutions to overlay for a given calendar [date]. The parent
  /// decides per-date whether that comes from the live fetch or from
  /// `substitution_history` (feature plan 7.5: past days -- whether just
  /// a day that already happened this week, or an entire past week being
  /// browsed -- pull from history instead of the live plan, which the
  /// portal itself no longer exposes them through).
  final List<Substitution> Function(DateTime date) substitutionsForDate;
  double calculateColumnHeight(List<TimeTableRow> rows) {
    double totalHeight = 0;
    for (var row in rows) {
      totalHeight +=
          (row.type == TimeTableRowType.lesson
              ? itemHeight
              : itemHeight - pauseHeight) +
          8;
    }
    return totalHeight;
  }

  int numOfWeeks(int year) {
    DateTime dec28 = DateTime(year, 12, 28);
    int dayOfDec28 = int.parse(DateFormat("D").format(dec28));
    return ((dayOfDec28 - dec28.weekday + 10) / 7).floor();
  }

  int getCurrentWeekNumber() {
    DateTime date = DateTime.now();
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) {
      woy = numOfWeeks(date.year - 1);
    } else if (woy > numOfWeeks(date.year)) {
      woy = 1;
    }
    return woy;
  }

  const TimeTableView({
    super.key,
    required this.data,
    required this.timetable,
    required this.settings,
    required this.updateSettings,
    required this.weekMonday,
    required this.substitutionsForDate,
    this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh!,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [
            Row(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  spacing: 8.0,
                  children: [
                    SizedBox(
                      height: headerHeight,
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("KW ${getCurrentWeekNumber()}"),
                          if (timetable.weekBadge != null &&
                              timetable.weekBadge!.isNotEmpty)
                            Text(
                                    AppLocalizations.of(
                                      context,
                                    ).timetableWeek(timetable.weekBadge!),
                                    style: TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      fontSize: 10,
                                    ),
                            ),
                          ],
                      ),
                    ),
                    for (var (row) in data.hours)
                      Container(
                        decoration: BoxDecoration(
                          color: row.type == TimeTableRowType.lesson
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        width: hourWidth,
                        height: row.type == TimeTableRowType.lesson
                            ? itemHeight
                            : pauseHeight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(row.label, style: TextStyle(fontSize: 12)),
                              ...(row.type == TimeTableRowType.lesson
                                  ? [
                                      Text(
                                        row.startTime.toFlutter().format(context),
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      Text(
                                        row.endTime.toFlutter().format(context),
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ]
                                  : []),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      var days = _itemDays(context);

                      if (!(settings['single-day'] ?? false)) {
                        return Row(
                          spacing: 4.0,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: days.map((e) {
                            return Expanded(
                              child: Stack(
                                children: [
                                  e,
                                  TimeMarkerWidget(
                                    data: data,
                                    timetable: timetable,
                                    settings: settings,
                                    day: days.indexOf(e),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      } else {
                        if (days.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        var initialIndex = (DateTime.now().weekday - 1) % 7;
                        if (initialIndex >= days.length) {
                          initialIndex = 0;
                        }
                        return SizedBox(
                          height: calculateColumnHeight(data.hours) + 48,
                          child: DefaultTabController(
                            length: days.length,
                            initialIndex: initialIndex,
                            child: TabBarView(
                              children: days.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4.0,
                                    right: 8.0,
                                  ),
                                  child: Stack(
                                    children: [
                                      e,
                                      TimeMarkerWidget(
                                        data: data,
                                        timetable: timetable,
                                        settings: settings,
                                        day: days.indexOf(e),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _itemDays(BuildContext context) {
    return [
      for (int i = 0; i < data.timetableDays.length; i++)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: headerHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(
                    Duration(days: data.weekdayIndices[i]),
                  );

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E(
                          Localizations.localeOf(context).languageCode,
                        ).format(date),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        date.format('dd.MM.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8.0),
            Builder(
              builder: (context) {
                // Feature 2 (Stundenplan-Overlay): resolve this column's
                // real calendar date, find that date's substitutions via
                // the caller-provided resolver (live fetch or history --
                // see [substitutionsForDate]'s doc comment), then run the
                // full decompose -> match -> merge pipeline once for this
                // day. `date`/`weekdayIndices[i]` mirror the header above
                // -- both must agree on which weekday column `i` actually is.
                final date = weekMonday.add(
                  Duration(days: data.weekdayIndices[i]),
                );
                final substitutionsForDay = substitutionsForDate(date);

                final blocksForDay = buildDisplayBlocksForDay(
                  subjects: data.timetableDays[i],
                  substitutions: substitutionsForDay,
                );

                return SizedBox(
                  height: calculateColumnHeight(data.hours),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          for (var (index, row) in data.hours.indexed)
                            ListItem(
                              iteration: index,
                              row: row,
                              data: data,
                              blocksForDay: blocksForDay,
                              width: constraints.maxWidth,
                              settings: settings,
                              updateSettings: updateSettings,
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
    ];
  }
}

class TimeMarkerWidget extends ConsumerStatefulWidget {
  const TimeMarkerWidget({
    super.key,
    required this.data,
    required this.timetable,
    required this.settings,
    this.day,
  });

  final TimeTableData data;
  final TimeTable timetable;
  final Map<String, dynamic> settings;
  final int? day;

  @override
  ConsumerState<TimeMarkerWidget> createState() => _TimeMarkerWidgetState();
}

class _TimeMarkerWidgetState extends ConsumerState<TimeMarkerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final int msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;
    _timer = Timer(Duration(milliseconds: msUntilNextMinute), () {
      if (mounted) setState(() {});
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double offset = 8;
    final now = DateTime.now();
    final nowTod = SphTimeOfDay(hour: now.hour, minute: now.minute);

    // Current day 0 Monday, 6 Sunday
    var currentDay = (DateTime.now().weekday - 1) % 7;

    if (currentDay != widget.day) {
      return SizedBox();
    }

    if (widget.data.hours.isEmpty || widget.data.timetableDays.isEmpty) {
      return const SizedBox();
    }

    if (nowTod < widget.data.hours.first.startTime) {
      return SizedBox();
    }

    if (nowTod > widget.data.hours.last.endTime) {
      return SizedBox();
    }

    for (var (lesson) in widget.data.hours) {
      // Check if lesson is already over and add the height of the lesson (or height of break)
      // If in the lesson add percentage of the lesson that has already passed
      final height = lesson.type == TimeTableRowType.lesson
          ? itemHeight
          : pauseHeight;
      if (nowTod >= lesson.startTime && nowTod <= lesson.endTime) {
        final diff =
            height *
            ((-nowTod.differenceInMinutes(lesson.startTime)) /
                lesson.startTime.differenceInMinutes(lesson.endTime));
        offset += diff;

        break;
      } else if (nowTod > lesson.endTime) {
        offset += height + 8;
      }
    }

    // Padding for the sidebar
    final barWidth = hourWidth + 4;
    final wholeWidth = (MediaQuery.of(context).size.width - barWidth - 10);
    final dayWidth = wholeWidth / widget.data.timetableDays.length;

    const double lineHeight = 2;
    return Positioned(
      top: headerHeight + offset - (lineHeight / 2),
      child: Container(
        color: Colors.red,
        width: (widget.settings['single-day'] ?? false)
            ? wholeWidth - 10
            : dayWidth,
        height: lineHeight,
      ),
    );
  }
}
