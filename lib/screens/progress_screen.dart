import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/progress_stats.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressStats? _stats;
  bool _failed = false;

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
        _stats = ProgressStats.fromLogs(logs, DateTime.now());
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final history = context.watch<UserProvider>().measurementHistory;
    final stats = _stats;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: theme.textSecondary),
        title: Text(
          'Progress',
          style: ftText(theme, size: 17, weight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: stats == null
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
            : ListView(
                padding: const EdgeInsets.all(Sp.x5),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${stats.streak}',
                          label: 'day streak',
                        ),
                      ),
                      const SizedBox(width: Sp.x3),
                      Expanded(
                        child: _Stat(
                          value: '${stats.workouts}',
                          label: stats.workouts == 1 ? 'workout logged' : 'workouts logged',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.x6),
                  const FtLabel('Last 7 days'),
                  FtCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 96,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < 7; i++)
                                Expanded(child: _Bar(value: stats.last7[i])),
                            ],
                          ),
                        ),
                        const SizedBox(height: Sp.x2),
                        Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _weekdays[DateTime.now()
                                            .subtract(Duration(days: 6 - i))
                                            .weekday -
                                        1],
                                    style: ftText(theme, size: 12, color: theme.textTertiary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Sp.x3),
                        Text(
                          '${(stats.weekAverage * 100).round()}% of checklist items done on average',
                          style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x6),
                  const FtLabel('Body measurements'),
                  _Trend(
                    title: 'Weight · kg',
                    points: _series(history, 'weight'),
                  ),
                  const SizedBox(height: Sp.x3),
                  _Trend(
                    title: 'Waist · cm',
                    points: _series(history, 'waist'),
                  ),
                  const SizedBox(height: Sp.x6),
                  const FtLabel('Recent workouts'),
                  if (stats.recent.isEmpty)
                    FtCard(
                      child: Text(
                        'Finish a workout in the Log tab and it shows up here.',
                        style: ftText(theme, size: 14, color: theme.textSecondary, height: 1.5),
                      ),
                    )
                  else
                    FtCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < stats.recent.length; i++) ...[
                            if (i > 0) const FtDivider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.x4,
                                vertical: Sp.x3,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stats.recent[i].session,
                                      style: ftText(theme, size: 15, weight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    '${stats.recent[i].sets} sets · ${stats.recent[i].date}',
                                    style: ftText(
                                      theme,
                                      size: 13,
                                      color: theme.textTertiary,
                                      tabular: true,
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
      ),
    );
  }

  static List<double> _series(List<Map<String, dynamic>> history, String key) {
    return [
      for (final e in history)
        if (double.tryParse('${e[key] ?? ''}') != null)
          double.parse('${e[key]}'),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return FtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: ftText(theme, size: 32, weight: FontWeight.w600, tabular: true),
          ),
          Text(label, style: ftText(theme, size: 13, color: theme.textTertiary)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final v = value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x1),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.surface2,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: Motion.base,
            curve: Motion.ease,
            builder: (context, h, _) => FractionallySizedBox(
              heightFactor: h == 0 ? 0.02 : h,
              child: Container(
                decoration: BoxDecoration(
                  color: v == 0 ? theme.border : theme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.title, required this.points});
  final String title;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final latest = points.isEmpty ? null : points.last;
    final delta = points.length > 1 ? points.last - points.first : null;

    return FtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: ftText(theme, size: 13, color: theme.textTertiary)),
              ),
              if (delta != null)
                Text(
                  '${delta > 0 ? '+' : ''}${fmtNum(double.parse(delta.toStringAsFixed(1)))} since first entry',
                  style: ftText(theme, size: 12, color: theme.textSecondary, tabular: true),
                ),
            ],
          ),
          const SizedBox(height: Sp.x1),
          Text(
            latest == null ? '--' : fmtNum(latest),
            style: ftText(theme, size: 24, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(height: Sp.x3),
          if (points.length < 2)
            Text(
              'Log measurements on at least two days to see a trend.',
              style: ftText(theme, size: 13, color: theme.textTertiary),
            )
          else
            SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _LinePainter(
                  points: points,
                  line: theme.accent,
                  dot: theme.accent,
                  grid: theme.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.line,
    required this.dot,
    required this.grid,
  });
  final List<double> points;
  final Color line;
  final Color dot;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = points.reduce((a, b) => a < b ? a : b);
    final hi = points.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    const pad = 4.0;

    Offset at(int i) => Offset(
      pad + (size.width - pad * 2) * i / (points.length - 1),
      pad + (size.height - pad * 2) * (1 - (points[i] - lo) / span),
    );

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(points.length - 1), 3.5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.line != line || old.grid != grid;
}
