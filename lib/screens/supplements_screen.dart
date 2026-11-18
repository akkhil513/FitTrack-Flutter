import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/file_download.dart';
import '../services/reminder_calendar.dart';
import '../services/supplement_catalog.dart';
import '../services/supplement_reminder.dart';
import '../theme/tokens.dart';
import '../widgets/input_decoration.dart';
import '../widgets/ui.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Small back control used at the top of both screens in this file.
class _BackRow extends StatelessWidget {
  const _BackRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, color: t.accent, size: 26),
              Text(label, style: ftText(t, size: 16, color: t.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Supplements list ────────────────────────────────────────────────────

class SupplementsScreen extends StatefulWidget {
  const SupplementsScreen({super.key});

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  bool _saving = false;

  Future<bool> _save(List<SupplementReminder> next) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      _toast(context, 'Sign in again to save reminders.');
      return false;
    }
    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().saveSupplementReminders(userId, next);
      return true;
    } catch (_) {
      if (mounted) {
        _toast(context, 'Could not save. Check your connection and try again.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(SupplementReminder r, bool on) async {
    if (_saving) return;
    final list = context.read<UserProvider>().supplementReminders;
    await _save([
      for (final e in list) e.id == r.id ? e.copyWith(enabled: on) : e,
    ]);
  }

  Future<void> _edit(SupplementReminder? existing) async {
    if (_saving) return;
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditor(existing: existing),
    );
    if (result == null || !mounted) return;

    final list = context.read<UserProvider>().supplementReminders;
    final List<SupplementReminder> next;
    if (result.delete) {
      next = list.where((e) => e.id != existing?.id).toList();
    } else {
      final saved = result.reminder!;
      next = [
        for (final e in list)
          if (e.id != saved.id) e,
        saved,
      ];
    }
    await _save(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final reminders = context.watch<UserProvider>().supplementReminders;
    final now = DateTime.now();
    final next = SupplementReminder.nextOf(reminders, now);
    final anyOn = reminders.any((r) => r.enabled);

    final subtitle = next != null
        ? 'Next: ${describeNext(next, now)}'
        : reminders.isEmpty
            ? 'No reminders yet'
            : 'All reminders are off';

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x2, Sp.x5, Sp.x8),
          children: [
            const _BackRow(label: 'Profile'),
            const SizedBox(height: Sp.x1),
            Text(
              'Reminders',
              style: ftText(t, size: 32, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              subtitle,
              style: ftText(t, size: 14, color: t.textTertiary, tabular: true),
            ),
            const SizedBox(height: Sp.x3),
            if (reminders.isEmpty)
              const FtEmpty(
                icon: Icons.alarm,
                title: 'No reminders yet',
                body: 'Add a time and what to take. Your phone will remind you.',
              )
            else
              for (final r in reminders)
                _ReminderRow(
                  reminder: r,
                  onTap: () => _edit(r),
                  onToggle: (on) => _toggle(r, on),
                ),
            const SizedBox(height: Sp.x4),
            FtButton(
              label: 'New reminder',
              secondary: true,
              loading: _saving,
              onPressed: reminders.length >= SupplementReminder.maxReminders
                  ? null
                  : () => _edit(null),
            ),
            const SizedBox(height: Sp.x6),
            FtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iPhone Calendar',
                    style: ftText(t, size: 15, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    'Your phone rings these on time, even with the app closed. '
                    'Add them once, and again after you change a time.',
                    style: ftText(t, size: 13, color: t.textSecondary),
                  ),
                  const SizedBox(height: Sp.x3),
                  FtButton(
                    label: 'Add to Calendar',
                    onPressed: anyOn
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CalendarSyncScreen(),
                              ),
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
  });
  final SupplementReminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final on = reminder.enabled;
    final primary = on ? t.textPrimary : t.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(vertical: Sp.x3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: reminder.clock,
                      style: ftText(
                        t,
                        size: 44,
                        weight: FontWeight.w300,
                        color: primary,
                        tabular: true,
                      ),
                      children: [
                        TextSpan(
                          text: ' ${reminder.meridiem}',
                          style: ftText(t, size: 18, color: primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    '${reminder.label} · ${reminder.daysLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ftText(
                      t,
                      size: 14,
                      color: on ? t.textSecondary : t.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit reminder',
              onPressed: onTap,
              icon: Icon(Icons.edit_outlined, size: 20, color: t.textSecondary),
            ),
            Semantics(
              label:
                  'Reminder at ${reminder.clock} ${reminder.meridiem}, ${reminder.label}',
              child: Switch(
                value: on,
                onChanged: onToggle,
                activeThumbColor: t.accentText,
                activeTrackColor: t.accent,
                inactiveThumbColor: t.textSecondary,
                inactiveTrackColor: t.surface2,
                trackOutlineColor: WidgetStatePropertyAll(t.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Editor (bottom sheet) ───────────────────────────────────────────────

class _EditorResult {
  const _EditorResult({this.reminder, this.delete = false});
  final SupplementReminder? reminder;
  final bool delete;
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.existing});
  final SupplementReminder? existing;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late DateTime _time;
  late final TextEditingController _label;
  late Set<int> _days;
  late bool _repeat;
  late ReminderKind _kind;
  String? _error;

  /// Bumped whenever the time is set from code, so the wheel picker rebuilds at the new time.
  int _pickerVersion = 0;
  bool _timeTouched = false;
  bool _suggesting = false;
  String? _suggestionTime;
  String? _suggestionNote;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _time = DateTime(2000, 1, 1, e?.hour ?? 8, e?.minute ?? 0);
    _label = TextEditingController(text: e?.label ?? '');
    _days = {...(e?.days ?? const {1, 2, 3, 4, 5, 6, 7})};
    _repeat = e?.repeat ?? false;
    _kind = e?.kind ?? ReminderKind.supplement;
    // An existing reminder already has a chosen time; do not overwrite it from the list.
    _timeTouched = e != null;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _isSupplement => _kind == ReminderKind.supplement;

  void _pickKind(ReminderKind k) {
    if (k == _kind) return;
    setState(() {
      final text = _label.text.trim();
      // Replace the label only when it is empty or still the previous kind's default.
      if (text.isEmpty || text == _kind.defaultLabel) {
        _label.text = k.defaultLabel;
        _label.selection = TextSelection.collapsed(offset: _label.text.length);
      }
      _kind = k;
      _error = null;
      _suggestionTime = null;
      _suggestionNote = null;
    });
  }

  void _setTime(int hour, int minute) {
    setState(() {
      _time = DateTime(2000, 1, 1, hour, minute);
      _pickerVersion++;
      _timeTouched = true;
    });
  }

  String _clockText(int hour, int minute) {
    final r = SupplementReminder(id: 'x', hour: hour, minute: minute, label: '');
    return '${r.clock} ${r.meridiem}';
  }

  void _pickFromList(SupplementSuggestion s) {
    setState(() {
      _label.text = addSupplementName(_label.text, s.name);
      _label.selection = TextSelection.collapsed(offset: _label.text.length);
      _error = null;
      _suggestionTime = null;
      _suggestionNote = null;
    });
    // Only move the time when the user has not chosen one yet.
    if (!_timeTouched) {
      setState(() {
        _time = DateTime(2000, 1, 1, s.hour, s.minute);
        _pickerVersion++;
      });
    }
  }

  Future<void> _askForTime() async {
    final name = _label.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add what to take first.');
      return;
    }
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      setState(() => _error = 'Sign in again to get a suggestion.');
      return;
    }
    setState(() {
      _suggesting = true;
      _error = null;
    });
    try {
      final result = await ApiService.suggestSupplementTime(userId, name);
      final parts = result['time'].toString().split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (!mounted) return;
      _setTime(hour, minute);
      setState(() {
        _suggestionTime = _clockText(hour, minute);
        _suggestionNote = result['reason']?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = catalogMatch(name);
      if (fallback != null) {
        _setTime(fallback.hour, fallback.minute);
        setState(() {
          _suggestionTime = _clockText(fallback.hour, fallback.minute);
          _suggestionNote =
              'The AI is unavailable, so this is the usual time for ${fallback.name}. '
              '${fallback.hint}.';
        });
      } else {
        setState(() {
          _suggestionTime = null;
          _suggestionNote = null;
          _error = 'Could not get a suggestion. Pick a time yourself.';
        });
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = _isSupplement ? 'Add what to take.' : 'Add a name.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Choose at least one day.');
      return;
    }
    Navigator.of(context).pop(
      _EditorResult(
        reminder: SupplementReminder(
          id: widget.existing?.id ?? SupplementReminder.newId(),
          hour: _time.hour,
          minute: _time.minute,
          label: label,
          days: _days,
          enabled: widget.existing?.enabled ?? true,
          repeat: _repeat,
          kind: _kind,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final editing = widget.existing != null;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final accentButton = TextButton.styleFrom(
      minimumSize: const Size(64, 44),
      foregroundColor: t.accent,
      textStyle: ftText(t, size: 16, weight: FontWeight.w500),
    );

    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sp.x5, Sp.x3, Sp.x5, Sp.x8 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton(
                  style: accentButton,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    editing ? 'Edit reminder' : 'New reminder',
                    textAlign: TextAlign.center,
                    style: ftText(t, size: 16, weight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  style: accentButton,
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ReminderKind.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: Sp.x2),
                itemBuilder: (_, i) {
                  final k = ReminderKind.all[i];
                  final on = k == _kind;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: k.title,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pickKind(k),
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        curve: Motion.ease,
                        padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? t.accent : t.surface2,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          k.title,
                          style: ftText(
                            t,
                            size: 13,
                            weight: FontWeight.w600,
                            color: on ? t.accentText : t.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Sp.x3),
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(Rd.panel),
                border: Border.all(color: t.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: t.isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      color: t.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  key: ValueKey(_pickerVersion),
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: _time,
                  onDateTimeChanged: (d) {
                    _time = d;
                    _timeTouched = true;
                  },
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            if (_isSupplement)
              FtButton(
                label: 'Suggest a time with AI',
                secondary: true,
                loading: _suggesting,
                onPressed: _askForTime,
              ),
            if (_isSupplement && _suggestionNote != null) ...[
              const SizedBox(height: Sp.x2),
              FtCard(
                selected: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested: $_suggestionTime',
                      style: ftText(t, size: 14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      _suggestionNote!,
                      style: ftText(t, size: 13, color: t.textSecondary),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      'General guidance, not medical advice. Ask your doctor '
                      'if you take medication.',
                      style: ftText(t, size: 12, color: t.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Sp.x5),
            FtLabel(_isSupplement ? 'What to take' : 'Name'),
            TextField(
              controller: _label,
              maxLength: SupplementReminder.maxLabelLength,
              textCapitalization: TextCapitalization.sentences,
              style: ftText(t, size: 15),
              decoration: fitTrackInput(_isSupplement ? 'Vitamin D3, Omega-3' : _kind.defaultLabel, t).copyWith(
                counterText: '',
                suffixIcon: !_isSupplement ? null : PopupMenuButton<SupplementSuggestion>(
                  tooltip: 'Suggested supplements',
                  color: t.surface,
                  icon: Icon(Icons.arrow_drop_down, color: t.textSecondary),
                  onSelected: _pickFromList,
                  itemBuilder: (_) => [
                    for (final s in supplementCatalog)
                      PopupMenuItem<SupplementSuggestion>(
                        value: s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: ftText(t, size: 15)),
                            Text(
                              s.hint,
                              style: ftText(t, size: 12, color: t.textTertiary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: Sp.x5),
            const FtLabel('Repeat'),
            Row(
              children: [
                for (var d = 1; d <= 7; d++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: d == 7 ? 0 : Sp.x1),
                      child: Semantics(
                        button: true,
                        selected: _days.contains(d),
                        label: _dayNames[d - 1],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _error = null;
                            if (!_days.add(d)) _days.remove(d);
                          }),
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            curve: Motion.ease,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _days.contains(d) ? t.accent : t.surface2,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              _dayLetters[d - 1],
                              style: ftText(
                                t,
                                size: 13,
                                weight: FontWeight.w600,
                                color: _days.contains(d)
                                    ? t.accentText
                                    : t.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Remind again after ${SupplementReminder.repeatAfterMinutes} min',
                    style: ftText(t, size: 15),
                  ),
                ),
                Switch(
                  value: _repeat,
                  onChanged: (v) => setState(() => _repeat = v),
                  activeThumbColor: t.accentText,
                  activeTrackColor: t.accent,
                  inactiveThumbColor: t.textSecondary,
                  inactiveTrackColor: t.surface2,
                  trackOutlineColor: WidgetStatePropertyAll(t.border),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x2),
              Text(
                _error!,
                style: ftText(t, size: 13, color: t.negative),
              ),
            ],
            if (editing) ...[
              const SizedBox(height: Sp.x3),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  foregroundColor: t.negative,
                  textStyle: ftText(t, size: 15, weight: FontWeight.w500),
                ),
                onPressed: () => Navigator.of(context)
                    .pop(const _EditorResult(delete: true)),
                child: const Text('Delete reminder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Add to Calendar ─────────────────────────────────────────────────────

class CalendarSyncScreen extends StatefulWidget {
  const CalendarSyncScreen({super.key});

  @override
  State<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends State<CalendarSyncScreen> {
  bool _busy = false;

  Future<void> _download(List<SupplementReminder> reminders) async {
    setState(() => _busy = true);
    try {
      final ok = await downloadTextFile(
        filename: 'fittrack-supplements.ics',
        mimeType: 'text/calendar;charset=utf-8',
        content: buildReminderCalendar(reminders),
      );
      if (mounted) {
        _toast(
          context,
          ok
              ? 'Calendar file downloaded. Open it to add the events.'
              : 'Saving a calendar file only works in the web app.',
        );
      }
    } catch (_) {
      if (mounted) _toast(context, 'Could not create the calendar file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final active = context
        .watch<UserProvider>()
        .supplementReminders
        .where((r) => r.enabled)
        .toList();

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x2, Sp.x5, Sp.x8),
          children: [
            const _BackRow(label: 'Reminders'),
            const SizedBox(height: Sp.x1),
            Text(
              'Add to Calendar',
              style: ftText(t, size: 32, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              active.isEmpty
                  ? 'Turn on at least one reminder first.'
                  : '${active.length} repeating '
                      '${active.length == 1 ? 'event' : 'events'}, each with an '
                      'alert at the time you set.',
              style: ftText(t, size: 14, color: t.textSecondary),
            ),
            const SizedBox(height: Sp.x5),
            const _Step(
              number: 1,
              title: 'Download the calendar file',
              body: 'Tap the button below.',
            ),
            const SizedBox(height: Sp.x2),
            const _Step(
              number: 2,
              title: 'Open the file',
              body: 'Open it from the download prompt, or from the Files app. '
                  'iPhone shows the events to import.',
            ),
            const SizedBox(height: Sp.x2),
            const _Step(
              number: 3,
              title: 'Tap Add All',
              body: 'Choose a calendar that has alerts turned on. '
                  'After that your phone rings on time, even offline.',
            ),
            const SizedBox(height: Sp.x4),
            FtCard(
              selected: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changed a time later?',
                    style: ftText(t, size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    'The calendar does not update by itself. Delete the old '
                    '"Take ..." events in Calendar, then add the file again.',
                    style: ftText(t, size: 13, color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            FtButton(
              label: 'Download calendar file',
              loading: _busy,
              onPressed: active.isEmpty ? null : () => _download(active),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return FtCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: ftText(t, size: 14, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ftText(t, size: 15, weight: FontWeight.w500)),
                const SizedBox(height: Sp.x1),
                Text(body, style: ftText(t, size: 13, color: t.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
