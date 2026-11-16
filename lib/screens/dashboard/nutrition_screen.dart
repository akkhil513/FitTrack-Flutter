import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/nutrition_targets.dart';
import '../../theme/tokens.dart';
import '../../widgets/input_decoration.dart';
import '../../widgets/ui.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  static const _waterGoal = 8;

  final _descController = TextEditingController();
  final String _date = DateTime.now().toIso8601String().split('T')[0];

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _templates = [];
  int _water = 0;
  bool _loading = true;
  bool _estimating = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  String? get _userId => context.read<AuthProvider>().userId;

  Future<void> _load() async {
    final id = _userId;
    if (id == null) return;
    try {
      final results = await Future.wait([
        ApiService.getLogByDate(id, _date),
        ApiService.getMealTemplates(id),
      ]);
      final log = results[0];
      final tpl = results[1];

      final entries = _decodeList(log['foodEntries']);
      final templates = _decodeList(tpl['mealTemplates']);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _templates = templates;
        _water = int.tryParse('${log['water'] ?? ''}'.trim()) ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<Map<String, dynamic>> _decodeList(Object? raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return [];
    try {
      final v = jsonDecode(text);
      if (v is List) {
        return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  int _sum(String key) => _entries.fold(
    0,
    (t, e) => t + ((num.tryParse('${e[key] ?? 0}') ?? 0).round()),
  );

  Future<bool> _persist() async {
    final id = _userId;
    if (id == null) return false;
    try {
      await ApiService.saveLog({
        'userId': id,
        'date': _date,
        'dayNumber': context.read<UserProvider>().dayNumber,
        'protein': '${_sum('protein')}',
        'calories': '${_sum('calories')}',
        'water': '$_water',
        'foodEntries': jsonEncode(_entries),
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection.')),
        );
      }
      return false;
    }
  }

  Future<void> _estimate() async {
    final text = _descController.text.trim();
    if (text.isEmpty || _estimating) return;
    setState(() {
      _estimating = true;
      _error = '';
    });
    try {
      final r = await ApiService.calculateMealMacros(text);
      final entry = {
        'name': text,
        'protein': _n(r['protein']),
        'calories': _n(r['calories']),
        'carbs': _n(r['carbs']),
        'fat': _n(r['fat']),
      };
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, entry];
        _descController.clear();
      });
      await _persist();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not estimate that meal. Try again or describe it differently.');
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  static int _n(Object? v) => (num.tryParse('${v ?? 0}') ?? 0).round();

  Future<void> _addTemplate(Map<String, dynamic> t) async {
    setState(() => _entries = [..._entries, Map<String, dynamic>.from(t)]);
    await _persist();
  }

  Future<void> _saveAsTemplate(Map<String, dynamic> e) async {
    final id = _userId;
    if (id == null) return;
    if (_templates.any((t) => t['name'] == e['name'])) return;
    final next = [..._templates, Map<String, dynamic>.from(e)];
    try {
      await ApiService.saveMealTemplates(id, next);
      if (mounted) setState(() => _templates = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the template.')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(int i) async {
    final id = _userId;
    if (id == null) return;
    final next = [..._templates]..removeAt(i);
    try {
      await ApiService.saveMealTemplates(id, next);
      if (mounted) setState(() => _templates = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the template.')),
        );
      }
    }
  }

  Future<void> _deleteEntry(int i) async {
    final removed = _entries[i];
    setState(() => _entries = [..._entries]..removeAt(i));
    if (!await _persist() && mounted) {
      setState(() => _entries = [..._entries]..insert(i, removed));
    }
  }

  Future<void> _setWater(int v) async {
    final prev = _water;
    setState(() => _water = v.clamp(0, 30));
    if (!await _persist() && mounted) setState(() => _water = prev);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    if (_loading) return const FtLoader();

    final targets = NutritionTargets.fromPlanText(
      context.watch<PlanProvider>().plan?['nutrition']?.toString(),
    );
    final protein = _sum('protein');
    final calories = _sum('calories');

    return ListView(
      padding: const EdgeInsets.all(Sp.x5),
      children: [
        FtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Total(
                      label: 'Calories',
                      value: calories,
                      target: targets.calories,
                      unit: 'kcal',
                    ),
                  ),
                  const SizedBox(width: Sp.x4),
                  Expanded(
                    child: _Total(
                      label: 'Protein',
                      value: protein,
                      target: targets.protein,
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),
              Text(
                'Carbs ${_sum('carbs')} g  ·  Fat ${_sum('fat')} g',
                style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.x3),
        FtCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water', style: ftText(theme, size: 15, weight: FontWeight.w500)),
                    Text(
                      '$_water of $_waterGoal glasses',
                      style: ftText(theme, size: 13, color: theme.textTertiary, tabular: true),
                    ),
                  ],
                ),
              ),
              _Round(icon: Icons.remove, onTap: _water > 0 ? () => _setWater(_water - 1) : null),
              const SizedBox(width: Sp.x2),
              _Round(icon: Icons.add, onTap: () => _setWater(_water + 1)),
            ],
          ),
        ),
        const SizedBox(height: Sp.x6),
        const FtLabel('Add a meal'),
        TextField(
          controller: _descController,
          minLines: 1,
          maxLines: 3,
          maxLength: 300,
          style: ftText(theme, size: 15),
          decoration: fitTrackInput('e.g. 2 eggs, 2 slices toast, 1 banana', theme)
              .copyWith(counterText: ''),
          onSubmitted: (_) => _estimate(),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: Sp.x2),
          Text(_error, style: ftText(theme, size: 13, color: theme.negative)),
        ],
        const SizedBox(height: Sp.x3),
        FtButton(label: 'Estimate and add', loading: _estimating, onPressed: _estimating ? null : _estimate),
        const SizedBox(height: Sp.x2),
        Text(
          'Macros are AI estimates. Treat them as a guide.',
          style: ftText(theme, size: 12, color: theme.textTertiary),
        ),
        if (_templates.isNotEmpty) ...[
          const SizedBox(height: Sp.x6),
          const FtLabel('Saved meals · tap to add, hold to remove'),
          Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x2,
            children: [
              for (var i = 0; i < _templates.length; i++)
                FtChip(
                  label: '${_templates[i]['name']}',
                  selected: false,
                  onTap: () => _addTemplate(_templates[i]),
                  onLongPress: () => _deleteTemplate(i),
                ),
            ],
          ),
        ],
        const SizedBox(height: Sp.x6),
        const FtLabel('Today'),
        if (_entries.isEmpty)
          FtCard(
            child: Text(
              'Nothing logged yet.',
              style: ftText(theme, size: 14, color: theme.textSecondary),
            ),
          )
        else
          FtCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0) const FtDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x2, Sp.x3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_entries[i]['name']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ftText(theme, size: 15, weight: FontWeight.w500),
                              ),
                              Text(
                                '${_n(_entries[i]['calories'])} kcal  ·  ${_n(_entries[i]['protein'])} g protein',
                                style: ftText(theme, size: 13, color: theme.textTertiary, tabular: true),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Save as meal',
                          onPressed: () => _saveAsTemplate(_entries[i]),
                          icon: Icon(
                            _templates.any((t) => t['name'] == _entries[i]['name'])
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 20,
                            color: theme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _deleteEntry(i),
                          icon: Icon(Icons.close, size: 20, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: Sp.x6),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
  });
  final String label;
  final int value;
  final int? target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final frac = target == null || target == 0 ? 0.0 : (value / target!).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ftText(theme, size: 13, color: theme.textTertiary)),
        const SizedBox(height: Sp.x1),
        Text(
          fmtNum(value),
          style: ftText(theme, size: 28, weight: FontWeight.w600, tabular: true),
        ),
        Text(
          target == null ? unit : 'of ${fmtNum(target!)} $unit',
          style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
        ),
        const SizedBox(height: Sp.x2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            backgroundColor: theme.surface2,
            valueColor: AlwaysStoppedAnimation(theme.accent),
          ),
        ),
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surface2,
          borderRadius: BorderRadius.circular(Rd.control),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? theme.textTertiary : theme.textPrimary,
        ),
      ),
    );
  }
}
