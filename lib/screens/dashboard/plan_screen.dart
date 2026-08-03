import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/theme_provider.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planProvider = context.watch<PlanProvider>();
    final theme = context.watch<ThemeProvider>();

    if (planProvider.isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.accent));
    }

    if (!planProvider.hasPlan) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No plan yet',
              style: TextStyle(color: theme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete onboarding to generate your plan',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
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
          // Strategy
          if (planProvider.plan!['strategy'] != null) ...[
            _PlanCard(
              emoji: '🎯',
              title: 'STRATEGY',
              color: theme.accent,
              content: planProvider.plan!['strategy'].toString(),
            ),
            const SizedBox(height: 12),
          ],

          // Week indicator
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEK ${planProvider.weekNumber}',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'AI-generated based on your profile',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AUTO-UPDATES\nEVERY MONDAY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Training
          Text(
            'THIS WEEK',
            style: TextStyle(
              color: theme.isDark
                  ? theme.textSecondary
                  : const Color(0xFF374151),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),

          if (planProvider.training != null) ...[
            ...[
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ].map((day) {
              final dayData = planProvider.training![day];
              if (dayData == null) return const SizedBox.shrink();
              final session = dayData['session']?.toString() ?? day;
              final exercises = (dayData['exercises'] as List? ?? []);
              final isRest =
                  dayData['isRestDay'] == true ||
                  session.toLowerCase().contains('rest') ||
                  session.toLowerCase().contains('recovery');
              return _DayCard(
                day: day.substring(0, 3).toUpperCase(),
                session: session,
                exercises: exercises.map((e) {
                  final name = e['name']?.toString() ?? '';
                  final sets = e['sets']?.toString() ?? '';
                  final reps = e['reps']?.toString() ?? '';
                  return '$name ${sets}×$reps';
                }).toList(),
                isRest: isRest,
              );
            }),
          ],

          const SizedBox(height: 16),

          // Supplements
          if (planProvider.plan!['supplements'] != null) ...[
            _PlanCard(
              emoji: '💊',
              title: 'SUPPLEMENTS',
              color: theme.orange,
              content: planProvider.plan!['supplements'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: 12),
          ],

          // Nutrition
          if (planProvider.plan!['nutrition'] != null) ...[
            _PlanCard(
              emoji: '🥩',
              title: 'NUTRITION',
              color: theme.green,
              content: planProvider.plan!['nutrition'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: 12),
          ],

          // Recovery
          if (planProvider.plan!['recovery'] != null) ...[
            _PlanCard(
              emoji: '😴',
              title: 'RECOVERY',
              color: theme.purple,
              content: planProvider.plan!['recovery'].toString(),
              asBullets: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.emoji,
    required this.title,
    required this.color,
    required this.content,
    this.asBullets = false,
  });
  final String emoji;
  final String title;
  final Color color;
  final String content;
  final bool asBullets;

  List<String> _toBulletLines(String value) {
    final normalized = value.replaceAll('\r', '\n');
    final byLine = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final lines = <String>[];
    for (final line in byLine) {
      final cleaned = line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
      final sentences = cleaned
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (sentences.isEmpty) continue;
      lines.addAll(sentences);
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: TextStyle(
              color: color,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (!asBullets)
            Text(
              content,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _toBulletLines(content)
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.session,
    required this.exercises,
    required this.isRest,
  });
  final String day;
  final String session;
  final List<String> exercises;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isRest
                  ? theme.surface2
                  : theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isRest ? theme.textSecondary : theme.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ...exercises.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '→ $e',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
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
