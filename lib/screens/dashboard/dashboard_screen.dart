import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';
import '../login_screen.dart';
import 'today_screen.dart';
import 'plan_screen.dart';
import 'log_screen.dart';
import 'nutrition_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    TodayScreen(onStartWorkout: () => _onTab(2)),
    const PlanScreen(),
    const LogScreen(),
    const NutritionScreen(),
    const ProfileScreen(),
  ];

  static const _tabs = [
    (icon: Icons.task_alt_outlined, label: 'Today'),
    (icon: Icons.event_note_outlined, label: 'Plan'),
    (icon: Icons.fitness_center_outlined, label: 'Log'),
    (icon: Icons.restaurant_outlined, label: 'Nutrition'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  void _onTab(int i) {
    setState(() => _currentIndex = i);

    // Reload plan when the Plan tab is opened.
    if (i == 1) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<PlanProvider>().loadPlan(auth.userId!);
      }
    }

    // Reload user when the Profile tab is opened.
    if (i == 4) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<UserProvider>().loadUser(auth.userId!);
      }
    }
  }

  void _signOut() {
    context.read<AuthProvider>().signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x3, Sp.x2, Sp.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Day ${user.dayNumber}',
                              style: ftText(
                                theme,
                                size: 28,
                                weight: FontWeight.w600,
                                tabular: true,
                              ),
                            ),
                            const SizedBox(width: Sp.x2),
                            Flexible(
                              child: Text(
                                'of ${user.challengeDuration}'
                                '  ·  Week ${user.calendarWeek}',
                                overflow: TextOverflow.ellipsis,
                                style: ftText(
                                  theme,
                                  size: 14,
                                  color: theme.textTertiary,
                                  tabular: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: _signOut,
                        icon: Icon(
                          Icons.logout,
                          size: 20,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const FtDivider(),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(top: BorderSide(color: theme.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTab(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _tabs[i].icon,
                            size: 20,
                            color: i == _currentIndex
                                ? theme.accent
                                : theme.textTertiary,
                          ),
                          const SizedBox(height: Sp.x1),
                          Text(
                            _tabs[i].label,
                            style: ftText(
                              theme,
                              size: 11,
                              weight: FontWeight.w500,
                              color: i == _currentIndex
                                  ? theme.textPrimary
                                  : theme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
