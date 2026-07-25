import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final List<Map<String, dynamic>> _exercises = [
    {
      'name': 'Barbell Bench Press',
      'sets': [
        {'weight': '75', 'reps': '12', 'done': false},
        {'weight': '75', 'reps': '12', 'done': false},
        {'weight': '85', 'reps': '8', 'done': false},
      ],
    },
    {
      'name': 'Incline DB Press',
      'sets': [
        {'weight': '40', 'reps': '10', 'done': false},
        {'weight': '40', 'reps': '10', 'done': false},
        {'weight': '40', 'reps': '9', 'done': false},
      ],
    },
  ];

  Widget _tagButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
        // Shared field decoration for the weight / reps inputs.
        InputDecoration setFieldDecoration(bool done) {
          final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: done ? theme.green.withValues(alpha: 0.3) : theme.border,
            ),
          );
          return InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: done
                ? theme.green.withValues(alpha: 0.08)
                : theme.surface2,
            border: border,
            enabledBorder: border,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PUSH A — CHEST & SHOULDERS',
                style: TextStyle(
                  color: Color(0xFFE8FF47),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mon, Jul 24',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),

              ..._exercises.asMap().entries.map((entry) {
                final i = entry.key;
                final ex = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    children: [
                      // Exercise header
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ex['name'],
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                _tagButton('HOW', const Color(0xFF47C8FF)),
                                const SizedBox(width: 6),
                                _tagButton('ALT', const Color(0xFFE8FF47)),
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
                              ? theme.green.withValues(alpha: 0.04)
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
                                    color: done
                                        ? theme.green
                                        : const Color(0xFFE8FF47),
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
                                  onChanged: (v) => set['weight'] = v,
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
                                  onChanged: (v) => set['reps'] = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() {
                                  (_exercises[i]['sets'] as List)[si]['done'] =
                                      !done;
                                }),
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

                      // Add set button
                      TextButton(
                        onPressed: () => setState(() {
                          (_exercises[i]['sets'] as List).add({
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8FF47),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'FINISH WORKOUT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
