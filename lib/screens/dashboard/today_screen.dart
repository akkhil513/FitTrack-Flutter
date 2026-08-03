import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Map<String, bool> _checked = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;
  String _todayKey = '';

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
            // Skip nutrition items — tracked in nutrition tab
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
          'label': 'Whey Protein — post workout',
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
          'label': 'Omega-3 Fish Oil',
          'category': 'supplement',
          'time': 'With lunch',
        },
        {
          'id': 'supp5',
          'label': 'Magnesium Glycinate',
          'category': 'supplement',
          'time': 'Before bed',
        },
        {
          'id': 'water1',
          'label': 'Drink 3.5L water',
          'category': 'recovery',
          'time': 'Throughout day',
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
          'label': '8000+ steps today',
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
    // Initialize all unchecked
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

    setState(() => _saving = true);

    try {
      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _todayKey,
        'dayNumber': 1,
        'checklist': jsonEncode(_checked),
      });
    } catch (_) {}

    if (mounted) setState(() => _saving = false);
  }

  int get _doneCount => _checked.values.where((v) => v).length;
  double get _scorePct => _items.isEmpty ? 0 : _doneCount / _items.length;

  String get _scoreMessage {
    final pct = _scorePct;
    if (pct == 1.0) return '🔥 PERFECT DAY!';
    if (pct >= 0.75) return 'Almost there — finish strong!';
    if (pct >= 0.5) return 'More than halfway — keep going!';
    if (pct > 0) return 'Good start — keep going!';
    return 'Complete all tasks to hit 100% today.';
  }

  Color _categoryColor(String category, ThemeProvider theme) {
    switch (category) {
      case 'supplement':
        return theme.accent;
      case 'training':
        return theme.blue;
      case 'recovery':
        return theme.green;
      default:
        return theme.accent;
    }
  }

  String _categoryIcon(String category) {
    switch (category) {
      case 'supplement':
        return '💊';
      case 'training':
        return '💪';
      case 'recovery':
        return '😴';
      default:
        return '✓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.accent));
    }

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
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '$_doneCount',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/${_items.length}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY SCORE',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _scorePct,
                              backgroundColor: theme.border,
                              valueColor: AlwaysStoppedAnimation(theme.accent),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _scoreMessage,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_saving) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    backgroundColor: theme.border,
                    valueColor: AlwaysStoppedAnimation(
                      theme.accent.withOpacity(0.5),
                    ),
                    minHeight: 2,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Group by category
          ...['supplement', 'training', 'recovery'].map((category) {
            final categoryItems = _items
                .where((i) => i['category'] == category)
                .toList();
            if (categoryItems.isEmpty) return const SizedBox.shrink();

            final color = _categoryColor(category, theme);
            final icon = _categoryIcon(category);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: theme.border)),
                  ],
                ),
                const SizedBox(height: 8),
                ...categoryItems.map((item) {
                  final id = item['id'] as String;
                  final done = _checked[id] ?? false;

                  return GestureDetector(
                    onTap: () => _toggle(id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: done ? color.withOpacity(0.08) : theme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: done ? color : theme.border,
                          width: done ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? color : Colors.transparent,
                              border: Border.all(
                                color: done ? color : theme.border,
                                width: 1.5,
                              ),
                            ),
                            child: done
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    color: done ? color : theme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: done
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: color,
                                  ),
                                ),
                                if ((item['time'] as String).isNotEmpty)
                                  Text(
                                    item['time'] as String,
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}
