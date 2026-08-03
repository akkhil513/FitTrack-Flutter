import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

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
  String _savedMsg = '';

  @override
  void initState() {
    super.initState();
    _logDate = DateTime.now().toIso8601String().split('T')[0];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExercises());
  }

  // Get today's day name
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
                            'done': true,
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
                return {
                  'name': ex['name']?.toString() ?? '',
                  'targetSets': sets,
                  'targetReps': reps,
                  'rest': ex['rest']?.toString() ?? '60s',
                  'sets': List.generate(
                    sets,
                    (i) => {
                      'weight': '',
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
    _autoSave();
  }

  void _autoSave() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

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
        'dayNumber': 1,
        'session': _session,
        'exercises': exercisesJson,
      });
    } catch (_) {}
  }

  void _finishWorkout() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();

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
        'dayNumber': 1,
        'session': _session,
        'exercises': exercisesJson,
        'notes': '',
      });

      if (mounted) {
        setState(() {
          _saving = false;
          _savedMsg = '✓ Workout saved!';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _savedMsg = '');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _tagButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, letterSpacing: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        InputDecoration setFieldDecoration(bool done) {
          final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: done ? theme.green.withOpacity(0.3) : theme.border,
            ),
          );
          return InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: done ? theme.green.withOpacity(0.08) : theme.surface2,
            border: border,
            enabledBorder: border,
          );
        }

        if (_loadingExercises) {
          return Center(child: CircularProgressIndicator(color: theme.accent));
        }

        // Rest day
        final plan = context.watch<PlanProvider>();
        final dayData = plan.training?[_todayName];
        final isRest = dayData?['isRestDay'] == true;

        if (isRest) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('😴', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(
                  'REST DAY',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recovery is part of the program.',
                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Foam roll, stretch, walk.',
                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session header
              Text(
                _session.toUpperCase(),
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_todayName}, $_logDate',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Empty state
              if (_exercises.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('💪', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          'No exercises for today',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate a plan first',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Exercise cards
              ..._exercises.asMap().entries.map((entry) {
                final i = entry.key;
                final ex = entry.value;
                final targetReps = ex['targetReps']?.toString() ?? '';
                final rest = ex['rest']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex['name'],
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (targetReps.isNotEmpty || rest.isNotEmpty)
                                    Text(
                                      '${targetReps.isNotEmpty ? "$targetReps reps" : ""}${rest.isNotEmpty ? "  ·  $rest rest" : ""}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _tagButton('HOW', theme.blue),
                                const SizedBox(width: 6),
                                _tagButton('ALT', theme.accent),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Sets header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                'SET',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'LBS',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'REPS',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Sets
                      ...(ex['sets'] as List).asMap().entries.map((setEntry) {
                        final si = setEntry.key;
                        final set = setEntry.value as Map<String, dynamic>;
                        final done = set['done'] as bool;

                        return Container(
                          color: done
                              ? theme.green.withOpacity(0.04)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${si + 1}',
                                  style: TextStyle(
                                    color: done ? theme.green : theme.accent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: set['weight'],
                                  style: TextStyle(
                                    color: done
                                        ? theme.green
                                        : theme.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: setFieldDecoration(done),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    set['weight'] = v;
                                    _autoSave();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: set['reps'],
                                  style: TextStyle(
                                    color: done
                                        ? theme.green
                                        : theme.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: setFieldDecoration(done),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    set['reps'] = v;
                                    _autoSave();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _toggleDone(i, si),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: done
                                        ? theme.green
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: done ? theme.green : theme.border,
                                    ),
                                  ),
                                  child: done
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.black,
                                          size: 18,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),

                      // Add set
                      TextButton(
                        onPressed: () => setState(() {
                          (ex['sets'] as List).add({
                            'weight': '',
                            'reps': '',
                            'done': false,
                          });
                        }),
                        child: Text(
                          '+ ADD SET',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Saved message
              if (_savedMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _savedMsg,
                    style: TextStyle(
                      color: theme.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Finish button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finishWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.accentText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? CircularProgressIndicator(color: theme.accentText)
                      : const Text(
                          'FINISH WORKOUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
