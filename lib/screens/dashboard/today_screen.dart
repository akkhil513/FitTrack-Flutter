import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final Map<String, bool> _checked = {
    'Whey Protein — post workout': false,
    'Creatine 5g': false,
    'Vitamin D3 with breakfast': false,
    'Omega-3 Fish Oil with lunch': false,
    'Magnesium Glycinate before bed': false,
    'Drink 3.5L water': false,
    'Complete today\'s workout': false,
    'Log all sets and reps': false,
    '8000+ steps today': false,
    'Sleep 7+ hours': false,
  };

  int get _doneCount => _checked.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_doneCount/${_checked.length}',
                      style: const TextStyle(
                        color: Color(0xFFE8FF47),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Score',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _doneCount / _checked.length,
                            backgroundColor: theme.border,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFE8FF47),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'SUPPLEMENTS',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),

              // Checklist items
              ..._checked.entries.map(
                (e) => GestureDetector(
                  onTap: () => setState(() => _checked[e.key] = !e.value),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: e.value
                          ? theme.green.withValues(alpha: 0.08)
                          : theme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: e.value ? theme.green : theme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          e.value ? Icons.check_circle : Icons.circle_outlined,
                          color: e.value ? theme.green : theme.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.key,
                            style: TextStyle(
                              color: e.value ? theme.green : theme.textPrimary,
                              fontSize: 13,
                              decoration: e.value
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
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
      },
    );
  }
}
