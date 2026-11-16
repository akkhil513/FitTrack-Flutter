import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/progress_stats.dart';
import '../../services/rest_timer.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<Map<String, dynamic>> _exercises = [];
  String _session = '';
  String _logDate = '';
  bool _loadingExercises = true;
  bool _saving = false;
  bool _showSaved = false;
  Timer? _saveDebounce;
  Timer? _restTimer;
  int _restLeft = 0;
  int _restTotal = 0;
  int _prefillGen = 0;

  @override
  void initState() {
    super.initState();
    _logDate = DateTime.now().toIso8601String().split('T')[0];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExercises());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restTotal = seconds;
      _restLeft = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restLeft <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        setState(() => _restLeft = 0);
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restLeft = 0);
  }

  /// Fills empty weights from the most recent earlier session with the same
  /// name and records a "last time" hint per exercise.
  Future<void> _applyLast(String userId) async {
    try {
      final logs = await ApiService.getLogs(userId);
      final earlier = logs
          .whereType<Map>()
          .where(
            (l) =>
                l['date'] != null &&
                l['date'].toString().compareTo(_logDate) < 0 &&
                l['session']?.toString() == _session &&
                ProgressStats.completedSets(l['exercises']) > 0,
          )
          .toList()
        ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      if (earlier.isEmpty || !mounted) return;

      final parsed = jsonDecode(earlier.first['exercises'].toString());
      if (parsed is! List) return;
      final byName = <String, List>{
        for (final ex in parsed)
          if (ex is Map && ex['sets'] is List) ex['name'].toString(): ex['sets'] as List,
      };

      setState(() {
        for (final ex in _exercises) {
          final prev = byName[ex['name'].toString()]
              ?.whereType<Map>()
              .where((s) => s['done'] == true && '${s['weight']}'.isNotEmpty)
              .toList();
          if (prev == null || prev.isEmpty) continue;
          final sets = ex['sets'] as List;
          for (var i = 0; i < sets.length; i++) {
            if (sets[i]['weight'].toString().isEmpty) {
              sets[i]['weight'] = '${(i < prev.length ? prev[i] : prev.last)['weight']}';
            }
          }
          final top = prev.last;
          ex['last'] = '${top['weight']} × ${top['reps']}';
        }
        _prefillGen++;
      });
    } catch (_) {
      // Prefill is a convenience; the log works without it.
    }
  }

  String get _todayName {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[DateTime.now().weekday % 7];
  }

  String get _prettyDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '$_todayName · ${months[now.month - 1]} ${now.day}';
  }

  int get _totalSets =>
      _exercises.fold(0, (sum, e) => sum + (e['sets'] as List).length);
  int get _doneSets => _exercises.fold(
    0,
    (sum, e) =>
        sum + (e['sets'] as List).where((s) => s['done'] == true).length,
  );

  void _loadExercises() async {
    final plan = context.read<PlanProvider>();
    final auth = context.read<AuthProvider>();

    // Try to load today's existing log first
    try {
      final log = await ApiService.getLogByDate(auth.userId!, _logDate);
      if (log['exercises'] != null &&
          log['exercises'].toString().trim().isNotEmpty &&
          log['exercises'].toString().trim() != ' ') {
        final parsed = jsonDecode(log['exercises'].toString());
        if (mounted) {
          setState(() {
            _session = log['session']?.toString() ?? '';
            _exercises = (parsed as List)
                .map(
                  (ex) => {
                    'name': ex['name'],
                    'sets': (ex['sets'] as List)
                        .map(
                          (s) => {
                            'weight': s['weight']?.toString() ?? '',
                            'reps': s['reps']?.toString() ?? '',
                            'done': s['done'] == true,
                          },
                        )
                        .toList(),
                  },
                )
                .toList();
            _loadingExercises = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Load from AI plan
    if (plan.training != null) {
      final dayData = plan.training![_todayName];
      if (dayData != null) {
        final isRest = dayData['isRestDay'] == true;
        _session = dayData['session']?.toString() ?? _todayName;

        if (!isRest) {
          final exercises = dayData['exercises'] as List? ?? [];
          if (mounted) {
            setState(() {
              _exercises = exercises.map((ex) {
                final sets = ex['sets'] as int? ?? 3;
                final reps = ex['reps']?.toString() ?? '10';
                final target = RegExp(r'\d+(\.\d+)?')
                        .firstMatch(ex['targetWeight']?.toString() ?? '')
                        ?.group(0) ??
                    '';
                return {
                  'name': ex['name']?.toString() ?? '',
                  'targetWeight': target,
                  'targetSets': sets,
                  'targetReps': reps,
                  'rest': ex['rest']?.toString() ?? '60s',
                  'sets': List.generate(
                    sets,
                    (i) => {
                      'weight': target,
                      'reps': reps.contains('-')
                          ? reps.split('-')[0]
                          : reps.replaceAll(RegExp(r'[^0-9]'), ''),
                      'done': false,
                    },
                  ),
                };
              }).toList();
              _loadingExercises = false;
            });
            _applyLast(auth.userId!);
          }
          return;
        }
      }
    }

    // Fallback — empty state
    if (mounted) {
      setState(() {
        _session = _todayName;
        _exercises = [];
        _loadingExercises = false;
      });
    }
  }

  void _toggleDone(int exIndex, int setIndex) {
    setState(() {
      final sets = _exercises[exIndex]['sets'] as List;
      sets[setIndex]['done'] = !(sets[setIndex]['done'] as bool);
    });
    if (_exercises[exIndex]['sets'][setIndex]['done'] == true) {
      _startRest(parseRestSeconds(_exercises[exIndex]['rest']?.toString()));
    }
    _saveDebounce?.cancel();
    _saveNow();
  }

  void _autoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  void _saveNow() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final dayNumber = context.read<UserProvider>().dayNumber;

    try {
      final exercisesJson = jsonEncode(
        _exercises
            .where(
              (e) => (e['sets'] as List).any(
                (s) => s['weight'].toString().isNotEmpty,
              ),
            )
            .map(
              (e) => {
                'name': e['name'],
                'sets': (e['sets'] as List)
                    .where((s) => s['weight'].toString().isNotEmpty)
                    .map(
                      (s) => {
                        'weight': s['weight'],
                        'reps': s['reps'],
                        'done': s['done'],
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      );

      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _logDate,
        'dayNumber': dayNumber,
        'session': _session,
        'exercises': exercisesJson,
      });
    } catch (_) {}
  }

  void _finishWorkout() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final dayNumber = context.read<UserProvider>().dayNumber;

    try {
      final exercisesJson = jsonEncode(
        _exercises
            .map(
              (e) => {
                'name': e['name'],
                'sets': (e['sets'] as List)
                    .map(
                      (s) => {
                        'weight': s['weight'],
                        'reps': s['reps'],
                        'done': s['done'],
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      );

      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _logDate,
        'dayNumber': dayNumber,
        'session': _session,
        'exercises': exercisesJson,
        'notes': '',
      });

      if (mounted) {
        setState(() {
          _saving = false;
          _showSaved = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSaved = false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (_loadingExercises) return const FtLoader();

    final plan = context.watch<PlanProvider>();
    final dayData = plan.training?[_todayName];
    final isRest = dayData?['isRestDay'] == true;

    if (isRest) {
      return const FtEmpty(
        icon: Icons.bedtime_outlined,
        title: 'Rest day',
        body: 'Walk, stretch or foam roll. Recovery is part of the plan.',
      );
    }

    return Stack(
      children: [
        _body(theme),
        if (_restLeft > 0)
          Positioned(
            left: Sp.x5,
            right: Sp.x5,
            bottom: Sp.x4,
            child: _restBar(theme),
          ),
      ],
    );
  }

  Widget _restBar(ThemeProvider theme) {
    final m = _restLeft ~/ 60;
    final sec = (_restLeft % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x2),
      decoration: BoxDecoration(
        color: theme.surface2,
        borderRadius: BorderRadius.circular(Rd.card),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Text('Rest', style: ftText(theme, size: 13, color: theme.textTertiary)),
          const SizedBox(width: Sp.x3),
          Text(
            '$m:$sec',
            style: ftText(theme, size: 20, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _restTotal == 0 ? 0 : _restLeft / _restTotal,
                minHeight: 4,
                backgroundColor: theme.border,
                valueColor: AlwaysStoppedAnimation(theme.accent),
              ),
            ),
          ),
          TextButton(
            onPressed: _skipRest,
            child: Text(
              'Skip',
              style: ftText(theme, size: 14, weight: FontWeight.w500, color: theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ThemeProvider theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Sp.x5,
        Sp.x5,
        Sp.x5,
        _restLeft > 0 ? 88 : Sp.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _session,
                      style: ftText(theme, size: 20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      _prettyDate,
                      style: ftText(theme, size: 13, color: theme.textTertiary),
                    ),
                  ],
                ),
              ),
              if (_totalSets > 0)
                Text(
                  '$_doneSets / $_totalSets sets',
                  style: ftText(
                    theme,
                    size: 13,
                    color: theme.textSecondary,
                    tabular: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x6),

          if (_exercises.isEmpty)
            FtCard(
              padding: const EdgeInsets.all(Sp.x6),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      'No exercises today',
                      style: ftText(theme, size: 16, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      'Your plan has no session for this day yet.',
                      textAlign: TextAlign.center,
                      style: ftText(theme, size: 14, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

          for (var i = 0; i < _exercises.length; i++) ...[
            _exerciseCard(theme, i),
            const SizedBox(height: Sp.x3),
          ],

          const SizedBox(height: Sp.x2),
          AnimatedOpacity(
            opacity: _showSaved ? 1 : 0,
            duration: Motion.fast,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: theme.positive),
                  const SizedBox(width: Sp.x2),
                  Text(
                    'Workout saved',
                    style: ftText(theme, size: 14, color: theme.positive),
                  ),
                ],
              ),
            ),
          ),
          FtButton(
            label: 'Finish workout',
            loading: _saving,
            onPressed: _saving ? null : _finishWorkout,
          ),
          const SizedBox(height: Sp.x6),
        ],
      ),
    );
  }

  Widget _exerciseCard(ThemeProvider theme, int i) {
    final ex = _exercises[i];
    final sets = ex['sets'] as List;
    final targetReps = ex['targetReps']?.toString() ?? '';
    final rest = ex['rest']?.toString() ?? '';
    final targetWeight = ex['targetWeight']?.toString() ?? '';
    final meta = [
      if (targetReps.isNotEmpty) '$targetReps reps',
      if (targetWeight.isNotEmpty) 'target $targetWeight lb',
      if (rest.isNotEmpty) '$rest rest',
    ].join('  ·  ');

    final headStyle = ftText(theme, size: 12, color: theme.textTertiary);
    final last = ex['last']?.toString() ?? '';

    return FtCard(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ex['name'].toString(),
            style: ftText(theme, size: 16, weight: FontWeight.w500),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: Sp.x1),
            Text(
              meta,
              style: ftText(
                theme,
                size: 13,
                color: theme.textTertiary,
                tabular: true,
              ),
            ),
          ],
          if (last.isNotEmpty) ...[
            const SizedBox(height: Sp.x1),
            Text(
              'Last time  $last',
              style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
            ),
          ],
          const SizedBox(height: Sp.x4),
          Row(
            children: [
              SizedBox(width: 28, child: Text('Set', style: headStyle)),
              const SizedBox(width: Sp.x3),
              Expanded(child: Text('Weight (lb)', style: headStyle)),
              const SizedBox(width: Sp.x2),
              Expanded(child: Text('Reps', style: headStyle)),
              const SizedBox(width: Sp.x2),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: Sp.x2),
          for (var si = 0; si < sets.length; si++) _setRow(theme, i, si),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                sets.add({'weight': '', 'reps': '', 'done': false});
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: theme.textSecondary),
                    const SizedBox(width: Sp.x1),
                    Text(
                      'Add set',
                      style: ftText(
                        theme,
                        size: 13,
                        weight: FontWeight.w500,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow(ThemeProvider theme, int exIndex, int si) {
    final set = (_exercises[exIndex]['sets'] as List)[si] as Map<String, dynamic>;
    final done = set['done'] as bool;

    final fieldStyle = ftText(
      theme,
      size: 20,
      weight: FontWeight.w500,
      tabular: true,
      color: done ? theme.textSecondary : theme.textPrimary,
    );

    InputDecoration deco() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: theme.surface2,
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Sp.x3,
        vertical: Sp.x3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.control),
        borderSide: BorderSide(color: theme.accent),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${si + 1}',
              style: ftText(
                theme,
                size: 16,
                weight: FontWeight.w500,
                tabular: true,
                color: done ? theme.accent : theme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: TextFormField(
              key: ValueKey('w-$exIndex-$si-$_prefillGen'),
              initialValue: set['weight'],
              style: fieldStyle,
              textAlign: TextAlign.center,
              decoration: deco(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                set['weight'] = v;
                _autoSave();
              },
            ),
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: TextFormField(
              initialValue: set['reps'],
              style: fieldStyle,
              textAlign: TextAlign.center,
              decoration: deco(),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                set['reps'] = v;
                _autoSave();
              },
            ),
          ),
          const SizedBox(width: Sp.x2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleDone(exIndex, si),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: FtCheck(done: done, size: 32)),
            ),
          ),
        ],
      ),
    );
  }
}
