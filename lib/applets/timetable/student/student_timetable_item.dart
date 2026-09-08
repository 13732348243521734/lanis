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

/// Paints a repeating diagonal (45°) two-color stripe pattern across
/// whatever size it's given, with a constant stripe width in logical
/// pixels regardless of the target size -- so stripes look consistent
/// whether the block is a single narrow lesson or a tall merged one,
/// unlike a fraction-based gradient whose stripe thickness would vary
/// with box size.
class DiagonalStripesPainter extends CustomPainter {
  final Color colorA;
  final Color colorB;
  final double stripeWidth;

  const DiagonalStripesPainter({
    required this.colorA,
    required this.colorB,
    this.stripeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paintA = Paint()..color = colorA;
    final paintB = Paint()..color = colorB;

    // Shear each stripe by size.height along x so it reads as a 45°
    // diagonal; start far enough to the left / extend far enough right
    // that the sheared band still fully covers the box at any aspect
    // ratio.
    final span = size.width + size.height;
    var x = -span;
    var i = 0;
    while (x < span) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, i.isEven ? paintA : paintB);
      x += stripeWidth;
      i++;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiagonalStripesPainter oldDelegate) {
    return colorA != oldDelegate.colorA ||
        colorB != oldDelegate.colorB ||
        stripeWidth != oldDelegate.stripeWidth;
  }
}


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
                if (overlay?.isCancelled == true)
                  modalSheetItem(
                    AppLocalizations.of(context).timetableCancelled,
                    Icons.event_busy_outlined,
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

  Widget _colorContainer(double width, {Widget? child, Color? stripeColor}) {
    final baseColor = color ?? Colors.transparent;
    final borderColor = stripeColor ?? baseColor;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge, // Clips any overflow, useful for the y axis
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: min(1, width / 3)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          stripeColor != null
              ? CustomPaint(
                  painter: DiagonalStripesPainter(
                    colorA: baseColor,
                    colorB: stripeColor,
                  ),
                )
              : ColoredBox(color: baseColor),
          Padding(padding: const EdgeInsets.all(4.0), child: child),
        ],
      ),
    );
  }

  /// Feature plan 7.3 display rules, as a diagonal-stripe pattern
  /// (subject color + a fixed signal color) rather than a flat override
  /// color -- readable without relying on color perception alone (e.g.
  /// for red/green color blindness), and still shows the subject's own
  /// color so the block stays identifiable at a glance.
  ///
  /// EVA and a cancelled lesson ("Entfall") both stripe red -- they're
  /// both "this lesson effectively isn't happening as planned" states,
  /// just with different causes; see [LessonOverlay.isEva] /
  /// [LessonOverlay.isCancelled]. Any other active change (a substitute
  /// teacher and/or a room change) stripes orange. `null` means no
  /// stripe -- the plain subject color renders as before.
  Color? _stripeSignalColor(LessonOverlay? overlay) {
    if (overlay == null) return null;
    if (overlay.isEva || overlay.isCancelled) return const Color(0xFFFF0000);
    if (overlay.vertreter != null || overlay.substituteRaum != null) {
      return Colors.orange.shade400;
    }
    return null;
  }

  /// One text line, struck through with an optional replacement value
  /// shown alongside (7.3: old teacher/room struck through, substitute
  /// shown next to it). With no [replacement] and no [strike], this is
  /// just a plain `Text` -- the common, non-overlaid case.
  ///
  /// The strikethrough line's own color is set explicitly to
  /// [style.color] (the already contrast-computed black/white text
  /// color for the current background) rather than relying on Flutter's
  /// default decoration color, so the line itself always reads correctly
  /// against red (EVA), orange (room change), or any curated/custom
  /// subject color -- not just the text.
  Widget _overlayableLine(
    String original,
    String? replacement,
    TextStyle style, {
    bool strike = false,
  }) {
    if (replacement == null && !strike) {
      return Text(
        original,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            original,
            style: style.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: style.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (replacement != null) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              replacement,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = block?.overlay;
    final stripeColor = _stripeSignalColor(overlay);
    final isEva = overlay?.isEva == true;
    final isCancelled = overlay?.isCancelled == true;
    // Both EVA and a cancelled lesson strike everything through -- see
    // _stripeSignalColor's doc comment for why they share treatment.
    final isFullyStruck = isEva || isCancelled;
    final overlayLabel = isEva ? 'EVA' : (isCancelled ? 'Entfällt' : null);

    // Striped backgrounds alternate between the subject's own (arbitrary,
    // curated/hash-based) color and a fixed signal color (red/orange).
    // Rather than computing contrast against two different colors, black
    // is used unconditionally when striped -- reads acceptably against
    // both typical subject colors and red/orange, matching common
    // hazard-stripe conventions (e.g. black-on-yellow warning tape).
    final textStyle = stripeColor != null
        ? const TextStyle(fontSize: 12, color: Colors.black)
        : TextStyle(
            fontSize: 12,
            color: color != null
                ? (color!.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white)
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
                stripeColor: stripeColor,
                child: onlyColor
                    ? SizedBox()
                    : (!onlyColor && block != null)
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _overlayableLine(
                                    block!.name,
                                    overlayLabel,
                                    textStyle,
                                    strike: isFullyStruck,
                                  ),
                                ),
                                if (block!.lehrer != null)
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _overlayableLine(
                                        block!.lehrer!,
                                        isFullyStruck ? null : overlay?.vertreter,
                                        textStyle,
                                        strike: isFullyStruck,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (block!.raum != null)
                              _overlayableLine(
                                block!.raum!,
                                isFullyStruck ? null : overlay?.substituteRaum,
                                textStyle,
                                strike: isFullyStruck,
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

    // Blocks "in progress" during this row's time span (used below for
    // parallel-lesson lane splitting).
    final blocksInRow = blocksForDay.where((b) {
      final times = _timesFor(b);
      if (times == null) return false;
      return row.startTime >= times.start && row.endTime <= times.end;
    }).toList();

    // Break rows (real pauses that aren't suppressed, and sandwiched free
    // periods) are handled together so consecutive ones -- e.g. a real
    // pause immediately followed by a free period with no lesson between
    // them -- merge into a single taller box instead of stacking as
    // separate same-height boxes.
    if (isBreakRow(row: row, blocksForDay: blocksForDay, rowForStunde: _rowForStunde)) {
      final previousRow = iteration > 0 ? data.hours[iteration - 1] : null;
      final previousIsBreak =
          previousRow != null &&
          isBreakRow(
            row: previousRow,
            blocksForDay: blocksForDay,
            rowForStunde: _rowForStunde,
          );

      if (previousIsBreak) {
        // Continuation of a break run whose box was already rendered at
        // the row where the run started.
        return ItemBlock.empty(
          height: 0,
          offset: verticalOffset,
          width: width,
          hOffset: horizontalOffset,
          updateSettings: updateSettings,
          settings: settings,
        );
      }

      // Start of a break run: measure how many consecutive following rows
      // are also break rows and render one box spanning all of them,
      // matching how a real multi-hour MergedLessonBlock's height is
      // computed (N rows of height H with 8px gaps = N*H + (N-1)*8).
      double runHeight = row.type == TimeTableRowType.lesson
          ? itemHeight
          : pauseHeight;
      var next = iteration + 1;
      while (next < data.hours.length) {
        final nextRow = data.hours[next];
        final nextIsBreak = isBreakRow(
          row: nextRow,
          blocksForDay: blocksForDay,
          rowForStunde: _rowForStunde,
        );
        if (!nextIsBreak) break;
        runHeight +=
            (nextRow.type == TimeTableRowType.lesson
                ? itemHeight
                : pauseHeight) +
            8;
        next++;
      }

      return ItemBlock(
        height: runHeight,
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
