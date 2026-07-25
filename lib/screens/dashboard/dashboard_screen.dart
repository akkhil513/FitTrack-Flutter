import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_background.dart';
import '../login_screen.dart';
import 'today_screen.dart';
import 'plan_screen.dart';
import 'log_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TodayScreen(),
    const PlanScreen(),
    const LogScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      body: AppBackground(
        theme: theme,
        motifs: const [
          Icons.fitness_center,
          Icons.monitor_heart,
          Icons.directions_run,
        ],
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Consumer<ThemeProvider>(
                builder: (context, theme, _) {
                  return Column(
                    children: [
                      // Yellow top bar — stays same
                      Container(
                        color: theme.headerYellow,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DAY ${user.dayNumber} / 100',
                              style: TextStyle(
                                color: theme.headerText,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '100 DAY CHALLENGE',
                              style: TextStyle(
                                color: theme.headerText.withValues(alpha: 0.7),
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bottom bar — theme aware
                      Container(
                        color: theme.surface.withValues(alpha: 0.8),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'HEY, ${user.firstName.toUpperCase()} 👋',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                auth.signOut();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.border),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SIGN OUT',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: theme.surface,
            selectedItemColor: theme.accent,
            unselectedItemColor: theme.textSecondary,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                label: 'TODAY',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: 'PLAN',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'LOG',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'PROFILE',
              ),
            ],
          );
        },
      ),
    );
  }
}
