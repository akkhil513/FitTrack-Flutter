import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/theme_provider.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>();
    final theme = context.watch<ThemeProvider>();

    if (plan.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE8FF47)),
      );
    }

    if (!plan.hasplan) {
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
          if (plan.plan!['strategy'] != null) ...[
            _PlanCard(
              emoji: '🎯',
              title: 'STRATEGY',
              color: const Color(0xFFE8FF47),
              content: plan.plan!['strategy'].toString(),
            ),
            const SizedBox(height: 12),
          ],

          // Training
          Text(
            'THIS WEEK',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),

          if (plan.training != null) ...[
            ...[
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ].map((day) {
              final dayData = plan.training![day];
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
          if (plan.plan!['supplements'] != null) ...[
            _PlanCard(
              emoji: '💊',
              title: 'SUPPLEMENTS',
              color: const Color(0xFFFF6B35),
              content: plan.plan!['supplements'].toString(),
            ),
            const SizedBox(height: 12),
          ],

          // Nutrition
          if (plan.plan!['nutrition'] != null) ...[
            _PlanCard(
              emoji: '🥩',
              title: 'NUTRITION',
              color: const Color(0xFF4ADE80),
              content: plan.plan!['nutrition'].toString(),
            ),
            const SizedBox(height: 12),
          ],

          // Recovery
          if (plan.plan!['recovery'] != null) ...[
            _PlanCard(
              emoji: '😴',
              title: 'RECOVERY',
              color: const Color(0xFFA78BFA),
              content: plan.plan!['recovery'].toString(),
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
  });
  final String emoji;
  final String title;
  final Color color;
  final String content;

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
          Text(
            content,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
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
                color: isRest ? theme.textSecondary : const Color(0xFFE8FF47),
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
