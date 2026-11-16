import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/input_decoration.dart';
import '../../widgets/ui.dart';
import '../onboarding_screen.dart';
import '../progress_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _changeStartDate(ThemeProvider theme) async {
    final user = context.read<UserProvider>();

    DateTime initial = DateTime.now();
    if (user.startDate.isNotEmpty) {
      try {
        initial = DateTime.parse(user.startDate);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final scheme = theme.isDark
            ? ColorScheme.dark(
                primary: theme.accent,
                onPrimary: theme.accentText,
                surface: theme.surface,
                onSurface: theme.textPrimary,
              )
            : ColorScheme.light(
                primary: theme.accent,
                onPrimary: theme.accentText,
                surface: theme.surface,
                onSurface: theme.textPrimary,
              );
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: scheme),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final newDate = picked.toIso8601String().split('T')[0];

    try {
      await ApiService.updateUser(
        userId: auth.userId!,
        challengeDuration: user.challengeDuration,
        startDate: newDate,
        firstName: user.firstName,
        lastName: user.lastName,
      );
      await user.loadUser(auth.userId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Start date set to $newDate')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the start date. Try again.')),
        );
      }
    }
  }

  void _changeDuration(ThemeProvider theme) async {
    final user = context.read<UserProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          'Challenge length',
          style: ftText(theme, size: 18, weight: FontWeight.w600),
        ),
        children: [
          for (final d in const [21, 45, 75, 100])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$d days',
                      style: ftText(theme, size: 15, weight: FontWeight.w500, tabular: true),
                    ),
                  ),
                  if (d == user.challengeDuration)
                    Icon(Icons.check, size: 18, color: theme.accent),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x2, Sp.x5, Sp.x2),
            child: Text(
              'Your plan was written for the length you chose at setup. Regenerate it to match.',
              style: ftText(theme, size: 12, color: theme.textTertiary, height: 1.4),
            ),
          ),
        ],
      ),
    );

    if (picked == null || picked == user.challengeDuration || !mounted) return;

    try {
      await ApiService.updateUser(
        userId: auth.userId!,
        challengeDuration: picked,
        startDate: user.startDate.isEmpty ? null : user.startDate,
        firstName: user.firstName,
        lastName: user.lastName,
      );
      await user.loadUser(auth.userId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Challenge set to $picked days')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change the challenge length. Try again.')),
        );
      }
    }
  }

  void _regeneratePlan(ThemeProvider theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Regenerate plan?',
          style: ftText(theme, size: 18, weight: FontWeight.w600),
        ),
        content: Text(
          'You will answer the setup questions again and get a new plan. Your logs are kept.',
          style: ftText(theme, size: 14, color: theme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: ftText(theme, size: 14, weight: FontWeight.w500, color: theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continue',
              style: ftText(theme, size: 14, weight: FontWeight.w500, color: theme.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _editMeasurements(ThemeProvider theme) async {
    final user = context.read<UserProvider>();
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final m = user.measurements;

    String show(Object? v) => v == null ? '' : fmtNum(num.tryParse('$v') ?? 0);
    final weight = TextEditingController(text: show(m['weight']));
    final waist = TextEditingController(text: show(m['waist']));
    final chest = TextEditingController(text: show(m['chest']));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Sp.x5,
          Sp.x5,
          Sp.x5,
          MediaQuery.of(ctx).viewInsets.bottom + Sp.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log measurements',
              style: ftText(theme, size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              'Saved as today\'s entry. Leave a field empty to keep its last value.',
              style: ftText(theme, size: 13, color: theme.textTertiary, height: 1.4),
            ),
            const SizedBox(height: Sp.x4),
            Row(
              children: [
                for (final f in [
                  ('Weight · kg', weight),
                  ('Waist · cm', waist),
                  ('Chest · cm', chest),
                ]) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$1,
                          style: ftText(theme, size: 12, color: theme.textTertiary),
                        ),
                        const SizedBox(height: Sp.x2),
                        TextField(
                          controller: f.$2,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: ftText(theme, size: 16, tabular: true),
                          decoration: fitTrackInput('--', theme),
                        ),
                      ],
                    ),
                  ),
                  if (f.$1 != 'Chest · cm') const SizedBox(width: Sp.x3),
                ],
              ],
            ),
            const SizedBox(height: Sp.x5),
            SizedBox(
              width: double.infinity,
              child: FtButton(
                label: 'Save',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ),
    );

    double? parse(TextEditingController c) {
      final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
      return (v != null && v > 0 && v < 500) ? v : null;
    }

    final w = parse(weight), wa = parse(waist), c = parse(chest);
    weight.dispose();
    waist.dispose();
    chest.dispose();

    if (saved != true || !mounted) return;
    if (w == null && wa == null && c == null) return;

    try {
      await user.saveMeasurements(userId, weight: w, waist: wa, chest: c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurements saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save measurements. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();
    final week = context.watch<PlanProvider>().weekNumber;

    if (user.isLoading) return const FtLoader();

    final initials =
        '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
            .toUpperCase();
    final m = user.measurements;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.border),
                ),
                child: Text(
                  initials,
                  style: ftText(theme, size: 16, weight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: Sp.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: ftText(theme, size: 18, weight: FontWeight.w600),
                    ),
                    Text(
                      '@${user.username}',
                      style: ftText(theme, size: 13, color: theme.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x6),

          // Progress
          FtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${(user.progress * 100).round()}%',
                      style: ftText(
                        theme,
                        size: 28,
                        weight: FontWeight.w600,
                        tabular: true,
                      ),
                    ),
                    const SizedBox(width: Sp.x2),
                    Text(
                      'of ${user.challengeDuration} days',
                      style: ftText(theme, size: 14, color: theme.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: user.progress.clamp(0.0, 1.0)),
                    duration: Motion.base,
                    curve: Motion.ease,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: theme.surface2,
                      valueColor: AlwaysStoppedAnimation(theme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x2),
                Text(
                  'Day ${user.dayNumber}  ·  ${user.daysLeft} days left',
                  style: ftText(
                    theme,
                    size: 13,
                    color: theme.textSecondary,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x3),

          // Measurements
          Row(
            children: [
              Expanded(
                child: Text(
                  'Measurements',
                  style: ftText(theme, size: 13, weight: FontWeight.w500, color: theme.textSecondary),
                ),
              ),
              FtButton(
                label: m.isEmpty ? 'Add' : 'Update',
                compact: true,
                onPressed: () => _editMeasurements(theme),
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          FtCard(
            padding: EdgeInsets.zero,
            onTap: () => _editMeasurements(theme),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _Measure(
                      label: 'Weight · kg',
                      value: _fmt(m['weight']),
                    ),
                  ),
                  Container(width: 1, color: theme.border),
                  Expanded(
                    child: _Measure(
                      label: 'Waist · cm',
                      value: _fmt(m['waist']),
                    ),
                  ),
                  Container(width: 1, color: theme.border),
                  Expanded(
                    child: _Measure(
                      label: 'Chest · cm',
                      value: _fmt(m['chest']),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.x3),
          FtCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.x4,
                vertical: Sp.x4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progress and history',
                      style: ftText(theme, size: 15, weight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.textTertiary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.x6),

          // Settings
          const FtLabel('Settings'),
          FtCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingRow(
                  title: 'Training plan',
                  subtitle: 'Week ${week > 0 ? week : 1}',
                  trailing: FtButton(
                    label: 'Regenerate',
                    secondary: true,
                    compact: true,
                    onPressed: () => _regeneratePlan(theme),
                  ),
                ),
                const FtDivider(),
                _SettingRow(
                  title: 'Challenge length',
                  subtitle: '${user.challengeDuration} days',
                  trailing: FtButton(
                    label: 'Change',
                    secondary: true,
                    compact: true,
                    onPressed: () => _changeDuration(theme),
                  ),
                ),
                const FtDivider(),
                _SettingRow(
                  title: 'Start date',
                  subtitle: user.startDate.isEmpty ? 'Not set' : user.startDate,
                  trailing: FtButton(
                    label: 'Change',
                    secondary: true,
                    compact: true,
                    onPressed: () => _changeStartDate(theme),
                  ),
                ),
                const FtDivider(),
                _SettingRow(
                  title: 'Appearance',
                  subtitle: theme.isDark ? 'Dark' : 'Light',
                  trailing: Switch(
                    value: theme.isDark,
                    onChanged: (_) => theme.toggleTheme(),
                    activeThumbColor: theme.accentText,
                    activeTrackColor: theme.accent,
                    inactiveThumbColor: theme.textSecondary,
                    inactiveTrackColor: theme.surface2,
                    trackOutlineColor: WidgetStatePropertyAll(theme.border),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x6),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: ftText(theme, size: 15, weight: FontWeight.w500)),
                  Text(
                    subtitle,
                    style: ftText(
                      theme,
                      size: 13,
                      color: theme.textTertiary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Measure extends StatelessWidget {
  const _Measure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x4, horizontal: Sp.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: ftText(theme, size: 24, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(height: Sp.x1),
          Text(
            label,
            style: ftText(theme, size: 12, color: theme.textTertiary),
          ),
        ],
      ),
    );
  }
}

String _fmt(Object? v) {
  final n = num.tryParse('${v ?? ''}');
  return n == null ? '--' : fmtNum(n);
}
