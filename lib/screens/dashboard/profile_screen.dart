import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _changeStartDate(BuildContext context, ThemeProvider theme) async {
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              onPrimary: theme.accentText,
              surface: theme.surface,
              onSurface: theme.textPrimary,
            ),
          ),
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
      );
      await user.loadUser(auth.userId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start date updated to $newDate'),
            backgroundColor: theme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _regeneratePlan(BuildContext context, ThemeProvider theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Regenerate Plan?',
          style: TextStyle(color: theme.textPrimary),
        ),
        content: Text(
          'You\'ll answer a few questions again so AI can build you a fresh plan. Your logs will be kept.',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'CONTINUE',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Navigate to onboarding - reuse existing flow.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();

    if (user.isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.accent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
                          .toUpperCase(),
                      style: TextStyle(
                        color: theme.accentText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatPill(
                          label: user.dayNumber == 0
                              ? 'DAY 0'
                              : 'DAY ${user.dayNumber}',
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: '${user.daysLeft} DAYS LEFT',
                          theme: theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${user.challengeDuration} DAY CHALLENGE',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '${(user.progress * 100).round()}%',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: user.progress,
                    backgroundColor: theme.surface2,
                    valueColor: AlwaysStoppedAnimation(theme.accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day ${user.dayNumber} of ${user.challengeDuration}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${user.daysLeft} days remaining',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.border),
                const SizedBox(height: 16),

                // Regenerate plan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Fitness Plan',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Week ${context.watch<PlanProvider>().weekNumber} · Tap to regenerate',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _regeneratePlan(context, theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'REGENERATE',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Measurements
          Row(
            children: [
              Expanded(
                child: _MeasurementCard(
                  label: 'WEIGHT',
                  value: user.measurements['weight']?.toString() ?? '--',
                  unit: 'kg',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasurementCard(
                  label: 'WAIST',
                  value: user.measurements['waist']?.toString() ?? '--',
                  unit: 'cm',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasurementCard(
                  label: 'CHEST',
                  value: user.measurements['chest']?.toString() ?? '--',
                  unit: 'cm',
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Challenge settings card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHALLENGE SETTINGS',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Start date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          user.startDate.isEmpty ? 'Not set' : user.startDate,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _changeStartDate(context, theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'CHANGE',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          theme.isDark ? Icons.dark_mode : Icons.light_mode,
                          color: theme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          theme.isDark ? 'Dark Mode' : 'Light Mode',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: theme.isDark,
                      onChanged: (_) => theme.toggleTheme(),
                      activeThumbColor: theme.accent,
                      activeTrackColor: theme.accent.withValues(alpha: 0.25),
                      inactiveThumbColor: theme.isDark
                          ? theme.surface2
                          : theme.textPrimary,
                      inactiveTrackColor: theme.border,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.theme});
  final String label;
  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accentLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: theme.accent, fontSize: 10)),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.theme,
  });
  final String label;
  final String value;
  final String unit;
  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: theme.accent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$label ($unit)',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
