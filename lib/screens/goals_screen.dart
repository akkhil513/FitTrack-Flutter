import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/goals.dart';
import '../theme/tokens.dart';
import '../widgets/input_decoration.dart';
import '../widgets/ui.dart';

String _statusText(GoalStatus s) => switch (s) {
      GoalStatus.noData => 'Log a measurement to start tracking',
      GoalStatus.reached => 'Goal reached',
      GoalStatus.ahead => 'Ahead of pace',
      GoalStatus.onTrack => 'On track',
      GoalStatus.behind => 'Behind pace',
    };

String _dateText(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _countdownText(int days) {
  if (days > 1) return '$days days to go';
  if (days == 1) return '1 day to go';
  if (days == 0) return 'Today is the day';
  return '${-days} ${days == -1 ? 'day' : 'days'} since';
}

DateTime? _startOf(UserProvider user) {
  if (user.startDate.isEmpty) return null;
  return DateTime.tryParse(user.startDate);
}

/// Compact card for other screens: countdown plus a one-line status; opens [GoalsScreen].
class GoalsSummaryCard extends StatelessWidget {
  const GoalsSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final user = context.watch<UserProvider>();
    final event = user.goalDate;
    final goals = user.goals;

    String subtitle;
    if (event == null) {
      subtitle = 'Set a target weight, waist and date';
    } else {
      final days = Goals.daysUntil(event, DateTime.now());
      subtitle = '${_countdownText(days)} · ${_dateText(event)}';
    }

    return FtCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoalsScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goals.isEmpty ? 'Goals' : 'Goals and countdown',
                    style: ftText(t, size: 15, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: ftText(t, size: 13, color: t.textSecondary, tabular: true),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final user = context.read<UserProvider>();
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final result = await showModalBottomSheet<Goals>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.read<ThemeProvider>().surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
      ),
      builder: (_) => _GoalsEditor(
        initial: user.goals,
        defaultDate: Goals.effectiveEventDate(
          Goals.empty,
          _startOf(user),
          user.challengeDuration,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await user.saveGoals(userId, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals saved')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save goals. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final user = context.watch<UserProvider>();
    final goals = user.goals;
    final event = user.goalDate;
    final start = _startOf(user);
    final now = DateTime.now();
    final history = user.measurementHistory;

    final cards = <Widget>[];
    if (event != null && start != null) {
      if (goals.targetWeight != null) {
        final ends = historyEnds(history, 'weight');
        cards.add(_MetricCard(
          title: 'Weight · kg',
          progress: MetricProgress.compute(
            start: ends.first,
            current: ends.latest,
            target: goals.targetWeight!,
            challengeStart: start,
            event: event,
            now: now,
          ),
        ));
      }
      if (goals.targetWaist != null) {
        final ends = historyEnds(history, 'waist');
        cards.add(_MetricCard(
          title: 'Waist · cm',
          progress: MetricProgress.compute(
            start: ends.first,
            current: ends.latest,
            target: goals.targetWaist!,
            challengeStart: start,
            event: event,
            now: now,
          ),
        ));
      }
    }

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text('Goals', style: ftText(t, size: 17, weight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.x5),
          children: [
            FtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event == null)
                    Text(
                      'No date yet',
                      style: ftText(t, size: 20, weight: FontWeight.w600),
                    )
                  else ...[
                    Text(
                      _countdownText(Goals.daysUntil(event, now)),
                      style: ftText(t, size: 28, weight: FontWeight.w600, tabular: true),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      _dateText(event) + (goals.eventDate == null ? ' · end of your challenge' : ''),
                      style: ftText(t, size: 14, color: t.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Sp.x3),
            if (cards.isEmpty)
              FtCard(
                child: Text(
                  'Set a target weight or waist and this page shows whether your pace will get you there by the date.',
                  style: ftText(t, size: 14, color: t.textSecondary, height: 1.5),
                ),
              )
            else
              for (final c in cards) ...[c, const SizedBox(height: Sp.x3)],
            const SizedBox(height: Sp.x2),
            FtButton(
              label: goals.isEmpty ? 'Set goals' : 'Edit goals',
              onPressed: () => _edit(context),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Pace compares how far you have moved toward the target with how much of the time has passed. '
              'It is a guide, not a prediction.',
              style: ftText(t, size: 12, color: t.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.progress});

  final String title;
  final MetricProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final p = progress;
    final good = p.status == GoalStatus.reached ||
        p.status == GoalStatus.ahead ||
        p.status == GoalStatus.onTrack;

    String fmt(double? v) => v == null ? '--' : fmtNum(double.parse(v.toStringAsFixed(1)));

    return FtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: ftText(t, size: 13, color: t.textTertiary)),
              ),
              Text(
                _statusText(p.status),
                style: ftText(
                  t,
                  size: 12,
                  weight: FontWeight.w600,
                  color: p.status == GoalStatus.noData
                      ? t.textTertiary
                      : (good ? t.positive : t.negative),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x1),
          Text(
            '${fmt(p.current)} → ${fmt(p.target)}',
            style: ftText(t, size: 24, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(height: Sp.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: t.surface2),
                FractionallySizedBox(
                  widthFactor: p.fraction,
                  child: Container(height: 8, color: t.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            p.status == GoalStatus.noData
                ? 'Add today\'s measurements from your profile.'
                : p.status == GoalStatus.reached
                    ? 'Target hit.'
                    : '${fmt(p.remaining)} to go · ${(p.fraction * 100).round()}% of the way, '
                        '${(p.timeFraction * 100).round()}% of the time used',
            style: ftText(t, size: 13, color: t.textSecondary, tabular: true),
          ),
        ],
      ),
    );
  }
}

class _GoalsEditor extends StatefulWidget {
  const _GoalsEditor({required this.initial, required this.defaultDate});

  final Goals initial;
  final DateTime? defaultDate;

  @override
  State<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends State<_GoalsEditor> {
  late final TextEditingController _weight;
  late final TextEditingController _waist;
  DateTime? _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    String show(double? v) => v == null ? '' : fmtNum(v);
    _weight = TextEditingController(text: show(widget.initial.targetWeight));
    _waist = TextEditingController(text: show(widget.initial.targetWaist));
    _date = widget.initial.eventDate;
  }

  @override
  void dispose() {
    _weight.dispose();
    _waist.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final base = _date ?? widget.defaultDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final w = _num(_weight);
    final wa = _num(_waist);
    if (_weight.text.trim().isNotEmpty &&
        (w == null || w < Goals.minWeight || w > Goals.maxWeight)) {
      setState(() => _error = 'Target weight must be between 20 and 400 kg.');
      return;
    }
    if (_waist.text.trim().isNotEmpty &&
        (wa == null || wa < Goals.minWaist || wa > Goals.maxWaist)) {
      setState(() => _error = 'Target waist must be between 30 and 250 cm.');
      return;
    }
    Navigator.of(context).pop(
      Goals(
        targetWeight: _weight.text.trim().isEmpty ? null : w,
        targetWaist: _waist.text.trim().isEmpty ? null : wa,
        eventDate: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.x5,
        Sp.x5,
        Sp.x5,
        MediaQuery.of(context).viewInsets.bottom + Sp.x5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goals', style: ftText(t, size: 18, weight: FontWeight.w600)),
            const SizedBox(height: Sp.x1),
            Text(
              'Leave a field empty to skip it.',
              style: ftText(t, size: 13, color: t.textTertiary),
            ),
            const SizedBox(height: Sp.x4),
            Row(
              children: [
                for (final f in [
                  ('Target weight · kg', _weight),
                  ('Target waist · cm', _waist),
                ]) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$1, style: ftText(t, size: 12, color: t.textTertiary)),
                        const SizedBox(height: Sp.x2),
                        TextField(
                          controller: f.$2,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: ftText(t, size: 16, tabular: true),
                          decoration: fitTrackInput('--', t),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (f.$1.startsWith('Target weight')) const SizedBox(width: Sp.x3),
                ],
              ],
            ),
            const SizedBox(height: Sp.x4),
            Text('Date', style: ftText(t, size: 12, color: t.textTertiary)),
            const SizedBox(height: Sp.x2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _date != null
                        ? _dateText(_date!)
                        : (widget.defaultDate != null
                            ? 'End of challenge · ${_dateText(widget.defaultDate!)}'
                            : 'Not set'),
                    style: ftText(t, size: 15, tabular: true),
                  ),
                ),
                FtButton(label: 'Pick date', secondary: true, compact: true, onPressed: _pickDate),
                if (_date != null) ...[
                  const SizedBox(width: Sp.x2),
                  FtButton(
                    label: 'Reset',
                    secondary: true,
                    compact: true,
                    onPressed: () => setState(() => _date = null),
                  ),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x3),
              Text(_error!, style: ftText(t, size: 13, color: t.negative)),
            ],
            const SizedBox(height: Sp.x5),
            SizedBox(
              width: double.infinity,
              child: FtButton(label: 'Save', onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
