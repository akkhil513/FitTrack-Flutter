import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/week_report.dart';
import '../../theme/tokens.dart';
import '../../widgets/input_decoration.dart';
import '../../widgets/ui.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _todayKey = GlobalKey();
  bool _scrolled = false;

  void _revealToday() {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _todayKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: Motion.fast,
        curve: Motion.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final planProvider = context.watch<PlanProvider>();
    final theme = context.watch<ThemeProvider>();

    if (planProvider.isLoading) return const FtLoader();

    if (!planProvider.hasPlan) {
      return const FtEmpty(
        icon: Icons.event_note_outlined,
        title: 'No plan yet',
        body: 'Finish setup and your plan will appear here.',
      );
    }

    final plan = planProvider.plan!;
    final todayName = _weekdays[DateTime.now().weekday - 1];
    if (planProvider.training?[todayName] != null) _revealToday();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${planProvider.weekNumber > 0 ? planProvider.weekNumber : 1}',
            style: ftText(theme, size: 20, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(height: Sp.x1),
          Text(
            planProvider.weekNumber > context.watch<UserProvider>().calendarWeek
                ? 'Built from your results. Starts Monday.'
                : 'Next week builds after your last training day.',
            style: ftText(theme, size: 13, color: theme.textTertiary),
          ),
          const SizedBox(height: Sp.x6),

          if (WeekReport.parse(plan['weekSummary']) case final report?) ...[
            _RecapCard(report: report),
            const SizedBox(height: Sp.x6),
          ],

          if (planProvider.training != null) ...[
            const FtLabel('This week'),
            FtCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final day in _weekdays)
                    if (planProvider.training![day] != null) ...[
                      if (day != _weekdays.first) const FtDivider(),
                      _DayRow(
                        key: day == todayName ? _todayKey : null,
                        day: day,
                        data: planProvider.training![day],
                        isToday: day == todayName,
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
          ],

          if (plan['strategy'] != null) ...[
            _TextSection(
              title: 'Strategy',
              content: plan['strategy'].toString(),
            ),
            const SizedBox(height: Sp.x6),
          ],

          if (plan['supplements'] != null) ...[
            _TextSection(
              title: 'Supplements',
              content: plan['supplements'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: Sp.x6),
          ],
          if (plan['nutrition'] != null) ...[
            _TextSection(
              title: 'Nutrition',
              content: plan['nutrition'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: Sp.x6),
          ],
          if (plan['recovery'] != null)
            _TextSection(
              title: 'Recovery',
              content: plan['recovery'].toString(),
              asBullets: true,
            ),
        ],
      ),
    );
  }
}

class _TextSection extends StatefulWidget {
  const _TextSection({
    required this.title,
    required this.content,
    this.asBullets = false,
  });
  final String title;
  final String content;
  final bool asBullets;

  @override
  State<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<_TextSection> {
  bool _open = false;

  List<String> _toBulletLines(String value) {
    final normalized = value.replaceAll('\r', '\n');
    final byLine = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final lines = <String>[];
    for (final line in byLine) {
      var cleaned = line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
      cleaned = cleaned.replaceFirst(RegExp(r'^\d+[.)](\s+|$)'), '').trim();
      if (cleaned.isEmpty) continue;
      final sentences = cleaned
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      lines.addAll(sentences);
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final body = ftText(theme, size: 14, height: 1.5);
    final lines = widget.asBullets ? _toBulletLines(widget.content) : <String>[];
    final canCollapse = widget.asBullets
        ? lines.length > 3
        : widget.content.length > 160;
    final shown = (!_open && widget.asBullets && canCollapse)
        ? lines.take(3).toList()
        : lines;

    return FtCard(
      padding: const EdgeInsets.all(Sp.x4),
      onTap: canCollapse ? () => setState(() => _open = !_open) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: ftText(theme, size: 15, weight: FontWeight.w500),
                ),
              ),
              if (canCollapse)
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: Motion.fast,
                  curve: Motion.ease,
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: theme.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          if (!widget.asBullets)
            Text(
              widget.content,
              maxLines: (!_open && canCollapse) ? 3 : null,
              overflow: (!_open && canCollapse)
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: ftText(theme, size: 14, color: theme.textSecondary, height: 1.5),
            )
          else
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.x2 + 1, right: Sp.x3),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(line, style: body)),
                  ],
                ),
              ),
          if (canCollapse && !_open)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x1),
              child: Text(
                'Show all',
                style: ftText(
                  theme,
                  size: 13,
                  weight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.day,
    required this.data,
    required this.isToday,
  });
  final String day;
  final dynamic data;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final session = data['session']?.toString() ?? day;
    final exercises = (data['exercises'] as List? ?? []);
    final isRest =
        data['isRestDay'] == true ||
        session.toLowerCase().contains('rest') ||
        session.toLowerCase().contains('recovery');

    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: isToday
          ? BoxDecoration(
              color: theme.accent.withValues(alpha: theme.isDark ? 0.14 : 0.09),
              border: Border.all(color: theme.accent, width: 1.5),
              borderRadius: BorderRadius.circular(Rd.control),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              day.substring(0, 3),
              style: ftText(
                theme,
                size: 13,
                weight: FontWeight.w600,
                color: isToday ? theme.accent : theme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session,
                        style: ftText(
                          theme,
                          size: 15,
                          weight: FontWeight.w500,
                          color: isRest ? theme.textTertiary : theme.textPrimary,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: Sp.x2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sp.x2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(Rd.chip),
                        ),
                        child: Text(
                          'Today',
                          style: ftText(
                            theme,
                            size: 11,
                            weight: FontWeight.w600,
                            color: theme.accentText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isRest && exercises.isNotEmpty) ...[
                  const SizedBox(height: Sp.x2),
                  for (final e in exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              e['name']?.toString() ?? '',
                              style: ftText(
                                theme,
                                size: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: Sp.x2),
                          Text(
                            '${e['sets'] ?? ''} × ${e['reps'] ?? ''}'
                            '${(e['targetWeight']?.toString().trim().isNotEmpty ?? false) ? ' · ${e['targetWeight']} lb' : ''}',
                            style: ftText(
                              theme,
                              size: 13,
                              color: theme.textTertiary,
                              tabular: true,
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'Replace ${e['name'] ?? 'exercise'}',
                              icon: Icon(Icons.swap_horiz, color: theme.textTertiary),
                              onPressed: () => _openSwap(
                                context,
                                day,
                                e['name']?.toString() ?? '',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openSwap(BuildContext context, String day, String exercise) async {
  if (exercise.isEmpty) return;
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.read<ThemeProvider>().surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
    ),
    builder: (_) => _SwapSheet(day: day, exercise: exercise),
  );
  if (done == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Replaced $exercise')),
    );
  }
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.day, required this.exercise});
  final String day;
  final String exercise;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<PlanProvider>().swapExercise(
            userId,
            day: widget.day,
            exercise: widget.exercise,
            reason: _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.x5,
        Sp.x5,
        Sp.x5,
        MediaQuery.of(context).viewInsets.bottom + Sp.x5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replace ${widget.exercise}',
              style: ftText(t, size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              'The AI picks a similar exercise for the same muscles. Its target weight starts empty.',
              style: ftText(t, size: 13, color: t.textTertiary, height: 1.4),
            ),
            const SizedBox(height: Sp.x4),
            TextField(
              controller: _reason,
              maxLength: 100,
              enabled: !_busy,
              style: ftText(t, size: 15),
              decoration: fitTrackInput('Optional: sore shoulder, no barbell…', t)
                  .copyWith(counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x2),
              Text(_error!, style: ftText(t, size: 13, color: t.negative)),
            ],
            const SizedBox(height: Sp.x4),
            SizedBox(
              width: double.infinity,
              child: FtButton(label: 'Suggest replacement', loading: _busy, onPressed: _go),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.report});
  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final shown = report.changes.take(5).toList();
    return FtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${report.week} recap',
            style: ftText(t, size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: Sp.x1),
          Text(
            report.changes.isEmpty
                ? report.sessionsLabel
                : '${report.sessionsLabel} · ${report.increases} ${report.increases == 1 ? 'lift' : 'lifts'} going up',
            style: ftText(t, size: 13, color: t.textSecondary, tabular: true),
          ),
          if (shown.isNotEmpty) const SizedBox(height: Sp.x3),
          for (final c in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.name, style: ftText(t, size: 13, color: t.textSecondary)),
                  ),
                  Text(
                    '${c.increased ? 'Up to' : 'Hold at'} ${c.weight}',
                    style: ftText(
                      t,
                      size: 13,
                      weight: FontWeight.w500,
                      color: c.increased ? t.positive : t.textTertiary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
