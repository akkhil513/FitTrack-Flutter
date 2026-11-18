import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/strength_stats.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'progress_screen.dart' show TrendLinePainter;

/// Personal records and a strength trend per exercise, built from the workout logs.
class StrengthScreen extends StatefulWidget {
  const StrengthScreen({super.key});

  @override
  State<StrengthScreen> createState() => _StrengthScreenState();
}

class _StrengthScreenState extends State<StrengthScreen> {
  List<ExerciseHistory>? _history;
  bool _failed = false;
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    try {
      final logs = await ApiService.getLogs(userId);
      if (!mounted) return;
      setState(() {
        _history = StrengthStats.fromLogs(logs);
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final history = _history;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text('Strength', style: ftText(t, size: 17, weight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: history == null
            ? (_failed
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FtEmpty(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load history',
                        body: 'Check your connection and try again.',
                      ),
                      FtButton(label: 'Retry', secondary: true, onPressed: _load),
                    ],
                  )
                : const FtLoader())
            : history.isEmpty
                ? const FtEmpty(
                    icon: Icons.fitness_center,
                    title: 'No lifts yet',
                    body: 'Complete sets with a weight in the Log tab and your records show up here.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(Sp.x5),
                    children: [
                      ..._records(t, history),
                      const FtLabel('Exercises'),
                      for (final h in history) ...[
                        _ExerciseCard(
                          history: h,
                          open: _open.contains(h.name),
                          onToggle: () => setState(() {
                            if (!_open.add(h.name)) _open.remove(h.name);
                          }),
                        ),
                        const SizedBox(height: Sp.x3),
                      ],
                      Text(
                        'Estimated 1-rep max uses the Epley formula (weight × (1 + reps ÷ 30)). '
                        'It is an estimate, not a tested max.',
                        style: ftText(t, size: 12, color: t.textTertiary, height: 1.5),
                      ),
                    ],
                  ),
      ),
    );
  }

  List<Widget> _records(ThemeProvider t, List<ExerciseHistory> history) {
    final prs = StrengthStats.recentRecords(history, DateTime.now());
    if (prs.isEmpty) return const [];
    return [
      const FtLabel('New records, last 2 weeks'),
      FtCard(
        selected: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final h in prs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x1),
                child: Text(
                  '${h.name}: ${fmtNum(h.latest.weight)} × ${h.latest.reps}',
                  style: ftText(t, size: 15, weight: FontWeight.w500, tabular: true),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: Sp.x6),
    ];
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.history,
    required this.open,
    required this.onToggle,
  });

  final ExerciseHistory history;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final best = history.bestE1rm;
    final last = history.latest;
    final points = [for (final s in history.sessions) s.e1rm];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: FtCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    history.name,
                    style: ftText(t, size: 15, weight: FontWeight.w600),
                  ),
                ),
                if (history.latestIsPr)
                  Text('PR', style: ftText(t, size: 12, weight: FontWeight.w700, color: t.accent)),
              ],
            ),
            const SizedBox(height: Sp.x1),
            Text(
              'Last: ${fmtNum(last.weight)} × ${last.reps} · Est. 1RM ${fmtNum(double.parse(best.toStringAsFixed(1)))}',
              style: ftText(t, size: 13, color: t.textSecondary, tabular: true),
            ),
            if (open) ...[
              const SizedBox(height: Sp.x3),
              if (points.length < 2)
                Text(
                  'Train this lift in two sessions to see a trend.',
                  style: ftText(t, size: 13, color: t.textTertiary),
                )
              else
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      points: points,
                      line: t.accent,
                      dot: t.accent,
                      grid: t.border,
                    ),
                  ),
                ),
              const SizedBox(height: Sp.x1),
              Text(
                '${history.sessions.length} sessions · since ${history.sessions.first.date}',
                style: ftText(t, size: 12, color: t.textTertiary, tabular: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
