import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/applets/timetable/student/timetable_row_visibility.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/root_nav.dart';

class ItemBlock extends StatelessWidget {
  final MergedLessonBlock? block;
  final TimeTableData? data;
  final double height;
  final Color? color;
  final bool empty;
  final double offset;
  final double width;
  final double? hOffset;
  final bool onlyColor;
  final bool disableAction;

  final Map<String, dynamic> settings;
  final Function updateSettings;

  const ItemBlock({
    super.key,
    this.block,
    this.data,
    required this.height,
    this.color,
    this.empty = false,
    required this.offset,
    required this.width,
    this.hOffset,
    this.onlyColor = false,
    required this.settings,
    required this.updateSettings,
    this.disableAction = false,
  });

  void showColorPicker(
    BuildContext context,
    Map<String, dynamic> settings,
    Function updateSettings,
    MergedLessonBlock lesson,
  ) {
    Color selectedColor = TimeTableHelper.getColorForLesson(settings, lesson);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (c) => {selectedColor = c},
              enableAlpha: false,
              labelTypes: [],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text(AppLocalizations.of(context).clear),
              onPressed: () {
                final colors = Map<String, dynamic>.from(
                  settings['lesson-colors'] is Map
                      ? settings['lesson-colors'] as Map
                      : const {},
                );
                colors.remove(lesson.id!.split('-')[0]);
                updateSettings('lesson-colors', colors);

                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text(AppLocalizations.of(context).select),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();

                final colors = Map<String, dynamic>.from(
                  settings['lesson-colors'] is Map
                      ? settings['lesson-colors'] as Map
                      : const {},
                );
                colors[lesson.id!.split('-')[0]] = selectedColor.toHexString(
                  enableAlpha: false,
                );
                updateSettings('lesson-colors', colors);
              },
            ),
          ],
        );
      },
    );
  }

  /// Resolves the real `TimeTableRow` (with clock times) for a single
  /// hour number, using [TimeTableRow.lessonIndex] -- which always equals
  /// the originating `TimetableSubject.stunde` (both come from the same
  /// underlying HTML row index; see liblanis' timetable parser). Returns
  /// `null` if [data] wasn't provided or the hour isn't found.
  TimeTableRow? _rowForStunde(int stunde) {
    for (final row in data?.hours ?? const <TimeTableRow>[]) {
      if (row.type == TimeTableRowType.lesson && row.lessonIndex == stunde) {
        return row;
      }
    }
    return null;
  }

  void showSubject(BuildContext context) {
    final startRow = block == null ? null : _rowForStunde(block!.startStunde);
    final endRow = block == null ? null : _rowForStunde(block!.endStunde);
    final overlay = block?.overlay;

    showRootModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              bottom: 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        block?.name ??
                            AppLocalizations.of(context).unknownLesson,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              showColorPicker(
                                context,
                                settings,
                                updateSettings,
                                block!,
                              );
                            },
                            icon: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          ),
                          if (block != null &&
                              (block?.id == null ||
                                  !block!.id!.startsWith('custom')))
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                                updateSettings('hidden-lessons', [
                                  ...?settings['hidden-lessons'],
                                  block!.id,
                                ]);
                                showSnackbar(
                                  context,
                                  AppLocalizations.of(
                                    context,
                                  ).lessonHidden(block!.name),
                                  seconds: 3,
                                );
                              },
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (block?.raum != null)
                  modalSheetItem(block!.raum!, Icons.place),
                if (startRow != null && endRow != null)
                  modalSheetItem(
                    "${startRow.startTime.toFlutter().format(context)} - ${endRow.endTime.toFlutter().format(context)} (${block!.stunden.length} ${block!.stunden.length == 1 ? "Stunde" : "Stunden"})",
                    Icons.access_time,
                  ),
                if (block?.lehrer != null)
                  modalSheetItem(block!.lehrer!, Icons.person),
                // Feature 2 (Stundenplan-Overlay): substitution info, if
                // this block matched one. No badge line here -- unlike
                // TimetableSubject, MergedLessonBlock doesn't carry the
                // original course/Kurs badge (GK/LK) through decompose +
                // merge; a real gap versus the old detail sheet, not
                // silently papered over.
                if (overlay?.isEva == true)
                  modalSheetItem(
                    AppLocalizations.of(context).timetableEva,
                    Icons.warning_amber_outlined,
                  ),
                if (overlay?.vertreter != null)
                  modalSheetItem(
                    AppLocalizations.of(
                      context,
                    ).timetableSubstituteTeacher(overlay!.vertreter!),
                    Icons.swap_horiz,
                  ),
                if (overlay?.substituteRaum != null)
                  modalSheetItem(
                    AppLocalizations.of(
                      context,
                    ).timetableSubstituteRoom(overlay!.substituteRaum!),
                    Icons.meeting_room_outlined,
                  ),
                if (overlay?.hinweis != null)
                  modalSheetItem(overlay!.hinweis!, Icons.info_outline),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget modalSheetItem(String content, IconData icon) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(icon, size: 24),
              ),
              Text(content, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        );
      },
    );
  }

  Widget _colorContainer(double width, {Widget? child, Color? overrideColor}) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge, // Clips any overflow, useful for the y axis
      decoration: BoxDecoration(
        border: Border.all(
          color: overrideColor ?? color ?? Colors.transparent,
          width: min(1, width / 3),
        ),
        color: overrideColor ?? color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(4.0),
      child: child,
    );
  }

  /// Feature plan 7.3 display rules. EVA takes priority: when set, the
  /// whole block renders red with everything struck through, regardless
  /// of any other overlay field.
  Color? _overlayBackgroundColor(LessonOverlay? overlay) {
    if (overlay == null) return null;
    if (overlay.isEva) return Colors.red.shade400;
    if (overlay.substituteRaum != null) return Colors.orange.shade400;
    return null;
  }

  /// One text line, struck through with an optional replacement value
  /// shown alongside (7.3: old teacher/room struck through, substitute
  /// shown next to it). With no [replacement] and no [strike], this is
  /// just a plain `Text` -- the common, non-overlaid case.
  Widget _overlayableLine(
    String original,
    String? replacement,
    TextStyle style, {
    bool strike = false,
  }) {
    if (replacement == null && !strike) {
      return Text(original, style: style, maxLines: 1);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          original,
          style: style.copyWith(decoration: TextDecoration.lineThrough),
          maxLines: 1,
        ),
        if (replacement != null) ...[
          const SizedBox(width: 4),
          Flexible(child: Text(replacement, style: style, maxLines: 1)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = block?.overlay;
    final overrideColor = _overlayBackgroundColor(overlay);
    final effectiveColor = overrideColor ?? color;
    final isEva = overlay?.isEva == true;

    TextStyle textStyle = TextStyle(
      fontSize: 12,
      color: effectiveColor != null
          ? effectiveColor.computeLuminance() > 0.5
                ? Colors.black
                : Colors.white
          : null,
    );

    double calcWidth = max(
      1,
      width - ((width > (hOffset ?? 0)) ? (hOffset ?? 0) : 0),
    );

    return Positioned(
      top: offset,
      left: hOffset,
      child: disableAction
          ? _colorContainer(calcWidth, child: SizedBox())
          : InkWell(
              onTap: block != null ? () => showSubject(context) : null,
              child: _colorContainer(
                calcWidth,
                overrideColor: overrideColor,
                child: onlyColor
                    ? SizedBox()
                    : (!onlyColor && block != null)
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              runAlignment: WrapAlignment.spaceBetween,
                              alignment: WrapAlignment.spaceBetween,
                              spacing: height % itemHeight >= 1.99
                                  ? 99999
                                  : 8.0,
                              children: [
                                _overlayableLine(
                                  block!.name,
                                  null,
                                  textStyle,
                                  strike: isEva,
                                ),
                                if (block!.lehrer != null)
                                  _overlayableLine(
                                    block!.lehrer!,
                                    isEva ? null : overlay?.vertreter,
                                    textStyle,
                                    strike: isEva,
                                  ),
                              ],
                            ),
                            if (block!.raum != null)
                              _overlayableLine(
                                block!.raum!,
                                isEva ? null : overlay?.substituteRaum,
                                textStyle,
                                strike: isEva,
                              ),
                          ],
                        ),
                      )
                    : SizedBox(),
              ),
            ),
    );
  }

  const ItemBlock.empty({
    super.key,
    required this.height,
    required this.offset,
    required this.width,
    required this.hOffset,
    required this.updateSettings,
    required this.settings,
  }) : block = null,
       data = null,
       color = null,
       onlyColor = false,
       disableAction = true,
       empty = true;
}

class ListItem extends StatelessWidget {
  final int iteration;
  final TimeTableRow row;
  final TimeTableData data;

  /// Precomputed via `buildDisplayBlocksForDay` for this day, once per
  /// day column (not once per row) -- see student_timetable_better_view.dart.
  final List<MergedLessonBlock> blocksForDay;
  final double width;
  final Map<String, dynamic> settings;
  final Function updateSettings;

  const ListItem({
    super.key,
    required this.iteration,
    required this.row,
    required this.data,
    required this.blocksForDay,
    required this.width,
    required this.settings,
    required this.updateSettings,
  });

  /// Resolves the real `TimeTableRow` (with clock times) for a single
  /// hour number, using [TimeTableRow.lessonIndex] -- see the identical
  /// helper (and its doc comment) on [ItemBlock].
  TimeTableRow? _rowForStunde(int stunde) {
    for (final r in data.hours) {
      if (r.type == TimeTableRowType.lesson && r.lessonIndex == stunde) {
        return r;
      }
    }
    return null;
  }

  /// A block's real start/end clock time, resolved via [_rowForStunde].
  /// `null` if either end of the block's `stunden` range isn't found in
  /// [data.hours] (shouldn't normally happen -- defensive, not silent:
  /// callers skip blocks this returns null for rather than guessing).
  ({SphTimeOfDay start, SphTimeOfDay end})? _timesFor(MergedLessonBlock block) {
    final startRow = _rowForStunde(block.startStunde);
    final endRow = _rowForStunde(block.endStunde);
    if (startRow == null || endRow == null) return null;
    return (start: startRow.startTime, end: endRow.endTime);
  }

  @override
  Widget build(BuildContext context) {
    double verticalOffset = 0;
    for (var j = 0; j < iteration; j++) {
      if (data.hours[j].type == TimeTableRowType.lesson) {
        verticalOffset += itemHeight;
      } else {
        verticalOffset += pauseHeight;
      }
      verticalOffset += 8;
    }

    double horizontalOffset = 0;

    // Blocks that start exactly at this row. Only lesson rows have a
    // meaningful lessonIndex to match against (pause rows use -1, which
    // no block.startStunde ever equals), matching the original
    // startTime-based check's behaviour for pause rows.
    final blocksHere = row.type == TimeTableRowType.lesson
        ? blocksForDay.where((b) => b.startStunde == row.lessonIndex).toList()
        : const <MergedLessonBlock>[];

    // Blocks "in progress" during this row's time span.
    final blocksInRow = blocksForDay.where((b) {
      final times = _timesFor(b);
      if (times == null) return false;
      return row.startTime >= times.start && row.endTime <= times.end;
    }).toList();

    // For pause rows, return a single Positioned widget
    if (row.type == TimeTableRowType.pause) {
      bool hidePause = false;
      for (var block in blocksInRow) {
        final times = _timesFor(block);
        if (times == null) continue;
        int numPauses = data.hours
            .where(
              (element) =>
                  element.type == TimeTableRowType.pause &&
                  element.startTime >= times.start &&
                  element.endTime <= times.end,
            )
            .length;
        if (numPauses > 0) {
          hidePause = true;
          break;
        }
      }

      // Also hide this pause if nothing is scheduled for the rest of the
      // day -- a break before the school day is effectively over shouldn't
      // still be shown.
      if (!hidePause &&
          shouldHideTrailingPause(
            pauseEnd: row.endTime,
            blocksForDay: blocksForDay,
            rowForStunde: _rowForStunde,
          )) {
        hidePause = true;
      }

      if (!hidePause) {
        return ItemBlock(
          height: pauseHeight,
          width: width,
          offset: verticalOffset,
          hOffset: horizontalOffset,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          onlyColor: true,
          settings: settings,
          updateSettings: updateSettings,
        );
      }
    }

    // A subject-less lesson row, sandwiched between an earlier and a
    // later lesson that day (e.g. a free period), gets the same
    // "große Pause" visual as a real break instead of staying invisible.
    if (row.type == TimeTableRowType.lesson &&
        blocksHere.isEmpty &&
        isSandwichedFreePeriod(
          stunde: row.lessonIndex,
          blocksForDay: blocksForDay,
        )) {
      return ItemBlock(
        height: itemHeight,
        width: width,
        offset: verticalOffset,
        hOffset: horizontalOffset,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        onlyColor: true,
        settings: settings,
        updateSettings: updateSettings,
      );
    }

    // If no block starts here, return an empty Positioned widget with a
    // pre-determined height (or 0 height)
    if (blocksHere.isEmpty || row.type == TimeTableRowType.pause) {
      return ItemBlock.empty(
        height: 0,
        offset: verticalOffset,
        width: width,
        hOffset: horizontalOffset,
        updateSettings: updateSettings,
        settings: settings,
      );
    }

    // Determine horizontal space: calculate max overlapping blocks
    int maxBlocksInRow = 0;
    for (var block in blocksHere) {
      final times = _timesFor(block);
      if (times == null) continue;
      int overlapping = blocksForDay.where((other) {
        final otherTimes = _timesFor(other);
        if (otherTimes == null) return false;
        return otherTimes.start >= times.start && otherTimes.start < times.end;
      }).length;
      if (overlapping > maxBlocksInRow) {
        maxBlocksInRow = overlapping;
      }
    }

    blocksInRow.sort((a, b) {
      final ta = _timesFor(a);
      final tb = _timesFor(b);
      if (ta == null || tb == null) return 0;
      return ta.start.compareTo(tb.start);
    });

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          for (var block in blocksHere)
            Builder(
              builder: (context) {
                int indexInRow = blocksInRow.indexOf(block);
                int maxNum = max(maxBlocksInRow, blocksInRow.length);

                double hOffset = (width / maxNum) * indexInRow;

                final times = _timesFor(block);
                int numPauses = times == null
                    ? 0
                    : data.hours
                          .where(
                            (element) =>
                                element.type == TimeTableRowType.pause &&
                                element.startTime >= times.start &&
                                element.endTime <= times.end,
                          )
                          .length;

                return ItemBlock(
                  block: block,
                  data: data,
                  height:
                      itemHeight * block.stunden.length +
                      ((block.stunden.length - 1) * 8) +
                      (numPauses * (pauseHeight + 8)),
                  color: TimeTableHelper.getColorForLesson(settings, block),
                  offset: verticalOffset,
                  // Calculate left offset based on block index and max overlapping blocks
                  hOffset: hOffset + (maxNum >= 2 ? 0 : 0),
                  width: (width / maxNum) - (maxNum >= 2 ? 2 : 0),
                  settings: settings,
                  updateSettings: updateSettings,
                  // Only show the color of the block to save resources
                  onlyColor:
                      blocksInRow.length > 3 &&
                      !(settings['single-day'] ?? false),
                  disableAction:
                      blocksInRow.length > 6 &&
                      !(settings['single-day'] ?? false),
                );
              },
            ),
        ],
      ),
    );
  }
}
