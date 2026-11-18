import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/exercise_library.dart';
import '../services/stretches.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Alternates the two demo frames of an exercise every ~800 ms, like a GIF. Falls back to a quiet placeholder
/// when the images cannot load, so a blocked network never breaks the screen.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({super.key, required this.urls, this.height = 220});
  final List<String> urls;
  final double height;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (widget.urls.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % widget.urls.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    Widget placeholder() => Center(
          child: Icon(Icons.fitness_center, color: t.textTertiary, size: 32),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rd.card),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: t.surface2,
        child: widget.urls.isEmpty
            ? placeholder()
            : Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < widget.urls.length; i++)
                    Opacity(
                      opacity: i == _frame ? 1 : 0,
                      child: Image.network(
                        widget.urls[i],
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => placeholder(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

/// "How to" sheet: moving demo, muscles, equipment and steps. [alternatives] and [onUseInstead] are given only
/// for today's workout, where swapping is allowed.
Future<void> showExerciseHowTo(
  BuildContext context,
  LibraryExercise exercise, {
  List<LibraryExercise> alternatives = const [],
  void Function(LibraryExercise)? onUseInstead,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.read<ThemeProvider>().surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
    ),
    builder: (sheetContext) => _HowToSheet(
      exercise: exercise,
      alternatives: alternatives,
      onUseInstead: onUseInstead == null
          ? null
          : (e) {
              Navigator.of(sheetContext).pop();
              onUseInstead(e);
            },
    ),
  );
}

class _HowToSheet extends StatelessWidget {
  const _HowToSheet({required this.exercise, required this.alternatives, required this.onUseInstead});
  final LibraryExercise exercise;
  final List<LibraryExercise> alternatives;
  final void Function(LibraryExercise)? onUseInstead;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final muscles = [..._unique(exercise.primary), ..._unique(exercise.secondary)];
    final facts = [
      if (exercise.primary.isNotEmpty) 'Main: ${exercise.primary.map(_titleCase).join(', ')}',
      if (exercise.secondary.isNotEmpty) 'Also: ${exercise.secondary.map(_titleCase).join(', ')}',
      if (exercise.equipment.isNotEmpty && exercise.equipment != 'None') 'Equipment: ${_titleCase(exercise.equipment)}',
      if (exercise.level.isNotEmpty) 'Level: ${_titleCase(exercise.level)}',
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(Sp.x5),
        children: [
          Text(exercise.name, style: ftText(t, size: 20, weight: FontWeight.w600)),
          const SizedBox(height: Sp.x4),
          ExerciseDemo(urls: exercise.imageUrls),
          const SizedBox(height: Sp.x4),
          if (muscles.isNotEmpty || facts.isNotEmpty)
            for (final f in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x1),
                child: Text(f, style: ftText(t, size: 13, color: t.textSecondary)),
              ),
          const SizedBox(height: Sp.x4),
          const FtLabel('Steps'),
          for (var i = 0; i < exercise.instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}', style: ftText(t, size: 14, color: t.textTertiary, tabular: true)),
                  ),
                  Expanded(
                    child: Text(exercise.instructions[i], style: ftText(t, size: 14, height: 1.45)),
                  ),
                ],
              ),
            ),
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: Sp.x4),
            const FtLabel('Alternatives for today'),
            for (final alt in alternatives)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x2),
                child: FtCard(
                  padding: const EdgeInsets.all(Sp.x3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alt.name, style: ftText(t, size: 14, weight: FontWeight.w500)),
                            if (alt.equipment.isNotEmpty && alt.equipment != 'None')
                              Text(
                                _titleCase(alt.equipment),
                                style: ftText(t, size: 12, color: t.textTertiary),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => showExerciseHowTo(context, alt),
                        child: Text('View', style: ftText(t, size: 13, color: t.textSecondary)),
                      ),
                      if (onUseInstead != null)
                        FtButton(
                          label: 'Use',
                          compact: true,
                          onPressed: () => onUseInstead!(alt),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static List<String> _unique(List<String> l) => l.toSet().toList();
}

/// A collapsible stretch checklist. Tapping a row ticks it; there are no timers. Ticks live only as long as the
/// card is on screen.
class StretchCard extends StatefulWidget {
  const StretchCard({super.key, required this.plan});
  final StretchPlan plan;

  @override
  State<StretchCard> createState() => _StretchCardState();
}

class _StretchCardState extends State<StretchCard> {
  bool _open = false;
  final _ticked = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final lib = ExerciseLibrary.cached;
    final plan = widget.plan;
    final done = plan.items.where((i) => _ticked.contains(i.id)).length;
    return FtCard(
      padding: const EdgeInsets.all(Sp.x4),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: ftText(t, size: 15, weight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(plan.subtitle, style: ftText(t, size: 12, color: t.textTertiary)),
                  ],
                ),
              ),
              Text(
                '$done / ${plan.items.length}',
                style: ftText(t, size: 13, color: done == plan.items.length ? t.positive : t.textSecondary, tabular: true),
              ),
              const SizedBox(width: Sp.x2),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: Motion.fast,
                curve: Motion.ease,
                child: Icon(Icons.expand_more, size: 20, color: t.textTertiary),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: Sp.x3),
            for (final item in plan.items)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x1),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        if (!_ticked.add(item.id)) _ticked.remove(item.id);
                      }),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: FtCheck(done: _ticked.contains(item.id), size: 24)),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: ftText(
                              t,
                              size: 14,
                              color: _ticked.contains(item.id) ? t.textTertiary : t.textPrimary,
                            ),
                          ),
                          Text(item.dose, style: ftText(t, size: 12, color: t.textTertiary)),
                        ],
                      ),
                    ),
                    if (lib?.byId(item.id) case final ex?)
                      IconButton(
                        tooltip: 'How to',
                        icon: Icon(Icons.play_circle_outline, size: 22, color: t.textTertiary),
                        onPressed: () => showExerciseHowTo(context, ex),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
