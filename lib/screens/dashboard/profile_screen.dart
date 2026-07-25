import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();

    if (user.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE8FF47)),
      );
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8FF47),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
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
                        _StatPill(label: 'DAY ${user.dayNumber}'),
                        const SizedBox(width: 8),
                        _StatPill(label: '${user.daysLeft} DAYS LEFT'),
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
                      '100 DAY CHALLENGE',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '${(user.progress * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFFE8FF47),
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
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFE8FF47)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day ${user.dayNumber} of 100',
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasurementCard(
                  label: 'WAIST',
                  value: user.measurements['waist']?.toString() ?? '--',
                  unit: 'cm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasurementCard(
                  label: 'CHEST',
                  value: user.measurements['chest']?.toString() ?? '--',
                  unit: 'cm',
                ),
              ),
            ],
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
                          color: theme.isDark
                              ? const Color(0xFFE8FF47)
                              : const Color(0xFF1A1A1A),
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
                      activeThumbColor: const Color(0xFFE8FF47),
                      activeTrackColor: theme.accent.withValues(alpha: 0.25),
                      inactiveThumbColor: const Color(0xFF1A1A1A),
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
  const _StatPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFE8FF47), fontSize: 10),
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

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
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8FF47),
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
