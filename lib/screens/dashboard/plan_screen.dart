import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planProvider = context.watch<PlanProvider>();
    final theme = context.watch<ThemeProvider>();

    if (planProvider.isLoading) return const FtLoader();

    if (!planProvider.hasPlan) {
      return const FtEmpty(
        icon: Icons.event_note_outlined,
        title: 'No plan yet',
        body: 'Finish setup and your plan will appear here.',
      );
    }

    final plan = planProvider.plan!;
    final todayName = _weekdays[DateTime.now().weekday - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${planProvider.weekNumber > 0 ? planProvider.weekNumber : 1}',
            style: ftText(theme, size: 20, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(height: Sp.x1),
          Text(
            planProvider.weekNumber > context.watch<UserProvider>().calendarWeek
                ? 'Built from your results. Starts Monday.'
                : 'Next week builds after your last training day.',
            style: ftText(theme, size: 13, color: theme.textTertiary),
          ),
          const SizedBox(height: Sp.x6),

          if (planProvider.training?[todayName] != null) ...[
            _TodayCard(day: todayName, data: planProvider.training![todayName]),
            const SizedBox(height: Sp.x6),
          ],

          if (planProvider.training != null) ...[
            const FtLabel('This week'),
            FtCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final day in _weekdays)
                    if (planProvider.training![day] != null) ...[
                      if (day != _weekdays.first) const FtDivider(),
                      _DayRow(
                        day: day,
                        data: planProvider.training![day],
                        isToday: day == todayName,
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
          ],

          if (plan['strategy'] != null) ...[
            _TextSection(
              title: 'Strategy',
              content: plan['strategy'].toString(),
            ),
            const SizedBox(height: Sp.x6),
          ],

          if (plan['supplements'] != null) ...[
            _TextSection(
              title: 'Supplements',
              content: plan['supplements'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: Sp.x6),
          ],
          if (plan['nutrition'] != null) ...[
            _TextSection(
              title: 'Nutrition',
              content: plan['nutrition'].toString(),
              asBullets: true,
            ),
            const SizedBox(height: Sp.x6),
          ],
          if (plan['recovery'] != null)
            _TextSection(
              title: 'Recovery',
              content: plan['recovery'].toString(),
              asBullets: true,
            ),
        ],
      ),
    );
  }
}

class _TextSection extends StatefulWidget {
  const _TextSection({
    required this.title,
    required this.content,
    this.asBullets = false,
  });
  final String title;
  final String content;
  final bool asBullets;

  @override
  State<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<_TextSection> {
  bool _open = false;

  List<String> _toBulletLines(String value) {
    final normalized = value.replaceAll('\r', '\n');
    final byLine = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final lines = <String>[];
    for (final line in byLine) {
      var cleaned = line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
      cleaned = cleaned.replaceFirst(RegExp(r'^\d+[.)](\s+|$)'), '').trim();
      if (cleaned.isEmpty) continue;
      final sentences = cleaned
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      lines.addAll(sentences);
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final body = ftText(theme, size: 14, height: 1.5);
    final lines = widget.asBullets ? _toBulletLines(widget.content) : <String>[];
    final canCollapse = widget.asBullets
        ? lines.length > 3
        : widget.content.length > 160;
    final shown = (!_open && widget.asBullets && canCollapse)
        ? lines.take(3).toList()
        : lines;

    return FtCard(
      padding: const EdgeInsets.all(Sp.x4),
      onTap: canCollapse ? () => setState(() => _open = !_open) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: ftText(theme, size: 15, weight: FontWeight.w500),
                ),
              ),
              if (canCollapse)
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: Motion.fast,
                  curve: Motion.ease,
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: theme.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          if (!widget.asBullets)
            Text(
              widget.content,
              maxLines: (!_open && canCollapse) ? 3 : null,
              overflow: (!_open && canCollapse)
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: ftText(theme, size: 14, color: theme.textSecondary, height: 1.5),
            )
          else
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.x2 + 1, right: Sp.x3),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(line, style: body)),
                  ],
                ),
              ),
          if (canCollapse && !_open)
            Padding(
              padding: const EdgeInsets.only(top: Sp.x1),
              child: Text(
                'Show all',
                style: ftText(
                  theme,
                  size: 13,
                  weight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.day, required this.data});
  final String day;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final session = data['session']?.toString() ?? day;
    final exercises = (data['exercises'] as List? ?? []);
    final isRest =
        data['isRestDay'] == true ||
        session.toLowerCase().contains('rest') ||
        session.toLowerCase().contains('recovery');
    final preview = exercises
        .take(3)
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final more = exercises.length - preview.length;

    return FtCard(
      selected: !isRest,
      padding: const EdgeInsets.all(Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today  ·  $day',
            style: ftText(
              theme,
              size: 13,
              weight: FontWeight.w500,
              color: isRest ? theme.textTertiary : theme.accent,
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            session,
            style: ftText(theme, size: 24, weight: FontWeight.w600),
          ),
          if (!isRest && exercises.isNotEmpty) ...[
            const SizedBox(height: Sp.x1),
            Text(
              '${exercises.length} exercises',
              style: ftText(theme, size: 13, color: theme.textTertiary, tabular: true),
            ),
            const SizedBox(height: Sp.x4),
            for (final name in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x1),
                child: Text(
                  name,
                  style: ftText(theme, size: 14, color: theme.textSecondary),
                ),
              ),
            if (more > 0)
              Text(
                '+ $more more',
                style: ftText(theme, size: 13, color: theme.textTertiary),
              ),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.data,
    required this.isToday,
  });
  final String day;
  final dynamic data;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final session = data['session']?.toString() ?? day;
    final exercises = (data['exercises'] as List? ?? []);
    final isRest =
        data['isRestDay'] == true ||
        session.toLowerCase().contains('rest') ||
        session.toLowerCase().contains('recovery');

    return Padding(
      padding: const EdgeInsets.all(Sp.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              day.substring(0, 3),
              style: ftText(
                theme,
                size: 13,
                weight: FontWeight.w500,
                color: isToday ? theme.accent : theme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session,
                  style: ftText(
                    theme,
                    size: 15,
                    weight: FontWeight.w500,
                    color: isRest ? theme.textTertiary : theme.textPrimary,
                  ),
                ),
                if (!isRest && exercises.isNotEmpty) ...[
                  const SizedBox(height: Sp.x2),
                  for (final e in exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              e['name']?.toString() ?? '',
                              style: ftText(
                                theme,
                                size: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: Sp.x3),
                          Text(
                            '${e['sets'] ?? ''} × ${e['reps'] ?? ''}'
                            '${(e['targetWeight']?.toString().trim().isNotEmpty ?? false) ? ' · ${e['targetWeight']} lb' : ''}',
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
