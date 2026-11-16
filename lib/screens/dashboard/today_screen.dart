import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/nutrition_targets.dart';
import '../../services/progress_stats.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.onStartWorkout});

  /// Switches the dashboard to the Log tab.
  final VoidCallback? onStartWorkout;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Map<String, bool> _checked = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _todayKey = '';
  ProgressStats _stats = ProgressStats.empty;
  int _protein = 0;
  int _calories = 0;
  int _water = 0;

  @override
  void initState() {
    super.initState();
    _todayKey = DateTime.now().toIso8601String().split('T')[0];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() async {
    // Build checklist from AI plan
    final plan = context.read<PlanProvider>();
    _buildItemsFromPlan(plan);

    // Load saved state from DB
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final log = await ApiService.getLogByDate(auth.userId!, _todayKey);
      int n(Object? v) => int.tryParse('${v ?? ''}'.trim()) ?? 0;
      _protein = n(log['protein']);
      _calories = n(log['calories']);
      _water = n(log['water']);
      ApiService.getLogs(auth.userId!).then((logs) {
        if (mounted) {
          setState(() => _stats = ProgressStats.fromLogs(logs, DateTime.now()));
        }
      });
      if (log['checklist'] != null &&
          log['checklist'].toString().trim().isNotEmpty &&
          log['checklist'].toString().trim() != ' ') {
        final saved = jsonDecode(log['checklist'].toString());
        final Map<String, bool> restoredChecked = {};
        for (final item in _items) {
          final id = item['id'] as String;
          restoredChecked[id] = saved[id] == true || saved[id] == 'true';
        }
        if (mounted) setState(() => _checked = restoredChecked);
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _buildItemsFromPlan(PlanProvider plan) {
    List<Map<String, dynamic>> items = [];

    if (plan.hasPlan) {
      // Parse dailyChecklist from AI plan
      try {
        final raw = plan.plan!['dailyChecklist'];
        if (raw != null &&
            raw.toString().trim().isNotEmpty &&
            raw.toString().trim() != '[]') {
          final parsed = jsonDecode(raw.toString()) as List;
          for (int i = 0; i < parsed.length; i++) {
            final item = parsed[i];
            final category = item['category']?.toString() ?? 'supplement';
            // Nutrition items are tracked elsewhere.
            if (category == 'nutrition') continue;
            items.add({
              'id': item['id']?.toString() ?? 'item_$i',
              'label': item['label']?.toString() ?? '',
              'category': category,
              'time': item['time']?.toString() ?? '',
            });
          }
        }
      } catch (_) {}
    }

    // Fallback default items if no AI plan
    if (items.isEmpty) {
      items = [
        {
          'id': 'supp1',
          'label': 'Whey protein, post workout',
          'category': 'supplement',
          'time': 'Post-workout',
        },
        {
          'id': 'supp2',
          'label': 'Creatine 5g',
          'category': 'supplement',
          'time': 'Post-workout',
        },
        {
          'id': 'supp3',
          'label': 'Vitamin D3',
          'category': 'supplement',
          'time': 'Morning',
        },
        {
          'id': 'supp4',
          'label': 'Omega-3 fish oil',
          'category': 'supplement',
          'time': 'With lunch',
        },
        {
          'id': 'supp5',
          'label': 'Magnesium glycinate',
          'category': 'supplement',
          'time': 'Before bed',
        },
        {
          'id': 'water1',
          'label': 'Drink 3.5L water',
          'category': 'recovery',
          'time': 'Throughout the day',
        },
        {
          'id': 'train1',
          'label': 'Complete today\'s workout',
          'category': 'training',
          'time': 'Evening',
        },
        {
          'id': 'train2',
          'label': 'Log all sets and reps',
          'category': 'training',
          'time': 'Post-workout',
        },
        {
          'id': 'rec1',
          'label': '8,000+ steps',
          'category': 'recovery',
          'time': 'Daily',
        },
        {
          'id': 'rec2',
          'label': 'Sleep 7+ hours',
          'category': 'recovery',
          'time': 'Before bed',
        },
      ];
    }

    _items = items;
    final Map<String, bool> checked = {};
    for (final item in items) {
      checked[item['id'] as String] = false;
    }
    _checked = checked;
  }

  void _toggle(String id) async {
    setState(() => _checked[id] = !(_checked[id] ?? false));
    await _saveChecklist();
  }

  Future<void> _saveChecklist() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final dayNumber = context.read<UserProvider>().dayNumber;

    try {
      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _todayKey,
        'dayNumber': dayNumber,
        'checklist': jsonEncode(_checked),
      });
    } catch (_) {}

  }

  int get _doneCount => _checked.values.where((v) => v).length;
  double get _scorePct => _items.isEmpty ? 0 : _doneCount / _items.length;

  String get _scoreMessage {
    final pct = _scorePct;
    if (pct == 1.0) return 'Everything done for today';
    if (pct >= 0.75) return 'Nearly there';
    if (pct >= 0.5) return 'Past halfway';
    if (pct > 0) return 'Under way';
    return 'Nothing checked yet';
  }

  static const _categories = <String, ({String title, IconData icon})>{
    'supplement': (title: 'Supplements', icon: Icons.medication_outlined),
    'training': (title: 'Training', icon: Icons.fitness_center_outlined),
    'recovery': (title: 'Recovery', icon: Icons.bedtime_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final userP = context.watch<UserProvider>();

    if (_loading) return const FtLoader();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.watch<PlanProvider>().weekNumber > userP.calendarWeek) ...[
            FtCard(
              selected: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${context.watch<PlanProvider>().weekNumber} plan is ready',
                    style: ftText(theme, size: 15, weight: FontWeight.w500),
                  ),
                  Text(
                    'New weights are in the Plan tab. They start Monday.',
                    style: ftText(theme, size: 13, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x3),
          ],
          ..._hero(theme),
          FtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Challenge',
                      style: ftText(
                        theme,
                        size: 13,
                        weight: FontWeight.w500,
                        color: theme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Day ${userP.dayNumber} of ${userP.challengeDuration}',
                      style: ftText(
                        theme,
                        size: 12,
                        color: theme.textTertiary,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x4),
                ChallengeGrid(
                  total: userP.challengeDuration,
                  current: userP.dayNumber,
                  todayFill: _scorePct,
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x8),

          // Groups
          for (final entry in _categories.entries)
            ..._buildGroup(theme, entry.key, entry.value),
        ],
      ),
    );
  }

  static const _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  List<Widget> _hero(ThemeProvider theme) {
    final plan = context.watch<PlanProvider>();
    final day = plan.training?[_dayNames[DateTime.now().weekday % 7]];
    final isRest = day?['isRestDay'] == true;
    final exList = (day?['exercises'] as List?) ?? const [];
    final sets = exList.fold<int>(
      0,
      (t, e) => t + (int.tryParse('${e is Map ? e['sets'] : ''}') ?? 3),
    );
    final session = day?['session']?.toString().trim() ?? '';
    final hasSession = day != null && !isRest && exList.isNotEmpty;

    final title = isRest
        ? 'Rest day'
        : hasSession
        ? (session.isEmpty ? 'Workout' : session)
        : 'No session today';
    final meta = hasSession
        ? '${exList.length} exercises · $sets sets'
        : isRest
        ? 'Recovery is part of the plan'
        : 'Your plan has no session for today';

    return theme.isDark
        ? _heroDark(theme, title, meta, hasSession)
        : _heroLight(theme, title, meta, hasSession);
  }

  // Dark: progress ring beside today's session, then a 7-day strip.
  List<Widget> _heroDark(
    ThemeProvider theme,
    String title,
    String meta,
    bool hasSession,
  ) {
    return [
      FtCard(
        padding: const EdgeInsets.all(Sp.x5),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(112, 112),
                    painter: _RingPainter(
                      fraction: _scorePct,
                      track: theme.surface2,
                      color: theme.accent,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_doneCount/${_items.length}',
                        style: ftText(theme, size: 24, weight: FontWeight.w600, tabular: true),
                      ),
                      Text(
                        'done',
                        style: ftText(theme, size: 12, color: theme.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.x5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's session",
                    style: ftText(theme, size: 12, color: theme.textTertiary),
                  ),
                  Text(title, style: ftText(theme, size: 20, weight: FontWeight.w600)),
                  Text(
                    meta,
                    style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
                  ),
                  if (hasSession) ...[
                    const SizedBox(height: Sp.x3),
                    FtButton(
                      label: 'Start workout',
                      compact: true,
                      onPressed: widget.onStartWorkout,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Sp.x3),
      FtCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Last 7 days',
                  style: ftText(theme, size: 13, weight: FontWeight.w500, color: theme.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${_stats.streak} day streak',
                  style: ftText(theme, size: 12, color: theme.textTertiary, tabular: true),
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < _stats.last7.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.x1),
                        child: Container(
                          height: (_stats.last7[i] * 40).clamp(4.0, 40.0),
                          decoration: BoxDecoration(
                            color: i == _stats.last7.length - 1
                                ? theme.accent
                                : (_stats.last7[i] >= ProgressStats.activeThreshold
                                      ? theme.textTertiary
                                      : theme.surface2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Sp.x3),
    ];
  }

  // Light: serif count, a bold workout card and four daily tiles.
  List<Widget> _heroLight(
    ThemeProvider theme,
    String title,
    String meta,
    bool hasSession,
  ) {
    final targets = NutritionTargets.fromPlanText(
      context.read<PlanProvider>().plan?['nutrition']?.toString(),
    );
    double frac(int v, int? t) => t == null || t == 0 ? 0 : (v / t).clamp(0.0, 1.0);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$_doneCount',
            style: ftText(theme, size: 56, weight: FontWeight.w600, tabular: true, height: 1.0),
          ),
          const SizedBox(width: Sp.x2),
          Text(
            'of ${_items.length} today',
            style: ftText(theme, size: 16, color: theme.textSecondary, tabular: true),
          ),
        ],
      ),
      const SizedBox(height: Sp.x1),
      Text(_scoreMessage, style: ftText(theme, size: 14, color: theme.textSecondary)),
      const SizedBox(height: Sp.x5),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Sp.x5),
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's workout",
              style: ftText(theme, size: 13, color: Colors.white),
            ),
            Text(
              title,
              style: ftText(theme, size: 30, weight: FontWeight.w600, color: Colors.white),
            ),
            Text(meta, style: ftText(theme, size: 14, color: Colors.white, tabular: true)),
            if (hasSession) ...[
              const SizedBox(height: Sp.x4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onStartWorkout,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Rd.panel),
                  ),
                  child: Text(
                    'Start workout',
                    style: ftText(theme, size: 16, weight: FontWeight.w600, color: const Color(0xFF8A3219)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: Sp.x3),
      Row(
        children: [
          Expanded(
            child: _Tile(label: 'Protein', value: fmtNum(_protein), unit: targets.protein == null ? 'g' : '/ ${targets.protein} g', fraction: frac(_protein, targets.protein)),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: _Tile(label: 'Calories', value: fmtNum(_calories), unit: targets.calories == null ? 'kcal' : '/ ${fmtNum(targets.calories!)}', fraction: frac(_calories, targets.calories)),
          ),
        ],
      ),
      const SizedBox(height: Sp.x3),
      Row(
        children: [
          Expanded(
            child: _Tile(label: 'Water', value: '$_water', unit: '/ 8 glasses', fraction: frac(_water, 8)),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: _Tile(label: 'Streak', value: '${_stats.streak}', unit: 'days', fraction: (_stats.streak / 7).clamp(0.0, 1.0)),
          ),
        ],
      ),
      const SizedBox(height: Sp.x3),
    ];
  }

  List<Widget> _buildGroup(
    ThemeProvider theme,
    String category,
    ({String title, IconData icon}) meta,
  ) {
    final groupItems = _items.where((i) => i['category'] == category).toList();
    if (groupItems.isEmpty) return const [];
    final doneInGroup = groupItems
        .where((i) => _checked[i['id'] as String] ?? false)
        .length;

    return [
      Row(
        children: [
          Icon(meta.icon, size: 16, color: theme.textSecondary),
          const SizedBox(width: Sp.x2),
          Text(
            meta.title,
            style: ftText(
              theme,
              size: 13,
              weight: FontWeight.w500,
              color: theme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$doneInGroup/${groupItems.length}',
            style: ftText(
              theme,
              size: 12,
              color: theme.textTertiary,
              tabular: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: Sp.x2),
      FtCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var n = 0; n < groupItems.length; n++) ...[
              if (n > 0) const FtDivider(),
              _row(theme, groupItems[n]),
            ],
          ],
        ),
      ),
      const SizedBox(height: Sp.x6),
    ];
  }

  Widget _row(ThemeProvider theme, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final done = _checked[id] ?? false;
    final time = item['time'] as String;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.x4,
          vertical: Sp.x3,
        ),
        child: Row(
          children: [
            FtCheck(done: done),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: Motion.fast,
                    curve: Motion.ease,
                    style: ftText(
                      theme,
                      size: 15,
                      color: done ? theme.textTertiary : theme.textPrimary,
                    ),
                    child: Text(item['label'] as String),
                  ),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: ftText(
                        theme,
                        size: 12,
                        color: theme.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.color});
  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 6.2831853, false, base..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        arc,
        -1.5707963,
        6.2831853 * fraction.clamp(0.0, 1.0),
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.color != color;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.unit,
    required this.fraction,
  });
  final String label;
  final String value;
  final String unit;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return FtCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ftText(theme, size: 13, color: theme.textSecondary)),
          const SizedBox(height: Sp.x1),
          Text.rich(
            TextSpan(
              text: value,
              style: ftText(theme, size: 24, weight: FontWeight.w600, tabular: true),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: ftText(theme, size: 12, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.surface2,
              valueColor: AlwaysStoppedAnimation(theme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
