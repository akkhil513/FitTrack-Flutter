import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/exercise_library.dart';
import '../../services/progress_stats.dart';
import '../../services/rest_timer.dart';
import '../../services/schedule.dart';
import '../../services/stretches.dart';
import '../../theme/tokens.dart';
import '../../widgets/exercise_demo.dart';
import '../../widgets/input_decoration.dart';
import '../../widgets/ui.dart';

/// Server limits mirrored here so the app refuses what the API would.
const _maxExercisesPerDay = 25;
const _maxNameLength = 60;

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<Map<String, dynamic>> _exercises = [];
  String _session = '';
  late DateTime _date;
  bool _loadingExercises = true;
  bool _saving = false;
  bool _showSaved = false;
  Timer? _saveDebounce;
  Timer? _restTimer;
  int _restLeft = 0;
  int _restTotal = 0;
  int _prefillGen = 0;

  /// Plan session (weekday name) this day covers; null for a custom workout or an unchosen day.
  String? _plannedDay;
  bool _rest = false;
  /// True once the user added, replaced or removed an exercise, so the saved list keeps exercises with no weights yet.
  bool _structureEdited = false;
  List<dynamic> _allLogs = [];
  int _loadGen = 0;

  String get _logDate => ProgressStats.dateKey(_date);
  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _date = dateOnly(DateTime.now());
    ExerciseLibrary.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDay());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restTotal = seconds;
      _restLeft = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restLeft <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        setState(() => _restLeft = 0);
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restLeft = 0);
  }

  /// Fills empty weights from the most recent earlier session with the same
  /// name and records a "last time" hint per exercise.
  Future<void> _applyLast(String userId) async {
    try {
      final logs = await ApiService.getLogs(userId);
      final earlier = logs
          .whereType<Map>()
          .where(
            (l) =>
                l['date'] != null &&
                l['date'].toString().compareTo(_logDate) < 0 &&
                l['session']?.toString() == _session &&
                ProgressStats.completedSets(l['exercises']) > 0,
          )
          .toList()
        ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      if (earlier.isEmpty || !mounted) return;

      final parsed = jsonDecode(earlier.first['exercises'].toString());
      if (parsed is! List) return;
      final byName = <String, List>{
        for (final ex in parsed)
          if (ex is Map && ex['sets'] is List) ex['name'].toString(): ex['sets'] as List,
      };

      setState(() {
        for (final ex in _exercises) {
          final prev = byName[ex['name'].toString()]
              ?.whereType<Map>()
              .where((s) => s['done'] == true && '${s['weight']}'.isNotEmpty)
              .toList();
          if (prev == null || prev.isEmpty) continue;
          final sets = ex['sets'] as List;
          for (var i = 0; i < sets.length; i++) {
            if (sets[i]['weight'].toString().isEmpty) {
              sets[i]['weight'] = '${(i < prev.length ? prev[i] : prev.last)['weight']}';
            }
          }
          final top = prev.last;
          ex['last'] = '${top['weight']} × ${top['reps']}';
        }
        _prefillGen++;
      });
    } catch (_) {
      // Prefill is a convenience; the log works without it.
    }
  }

  DateTime? get _challengeStart {
    final s = context.read<UserProvider>().startDate;
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    return d == null ? null : dateOnly(d);
  }

  /// Oldest day that can still be logged: the server accepts 14 days back. Days before the challenge start are
  /// allowed too, so a session done just before starting can still be recorded.
  DateTime get _earliestDate => dateOnly(DateTime.now()).subtract(const Duration(days: 14));

  int _dayNumberFor(DateTime d) {
    final start = _challengeStart;
    if (start == null) return 1;
    final n = d.difference(start).inDays + 1;
    return n < 1 ? 0 : n;
  }

  String get _prettyDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = weekdayNames[_date.weekday - 1].substring(0, 3);
    return '$day, ${months[_date.month - 1]} ${_date.day}';
  }

  int get _totalSets =>
      _exercises.fold(0, (sum, e) => sum + (e['sets'] as List).length);
  int get _doneSets => _exercises.fold(
    0,
    (sum, e) =>
        sum + (e['sets'] as List).where((s) => s['done'] == true).length,
  );

  Map<String, dynamic> _blankSet(String weight, String reps) =>
      {'weight': weight, 'reps': reps, 'done': false};

  /// Builds the editable exercise list for one plan session.
  List<Map<String, dynamic>> _exercisesFromPlan(Map day) {
    final exercises = day['exercises'] as List? ?? [];
    return exercises.map<Map<String, dynamic>>((ex) {
      final sets = int.tryParse('${ex['sets']}') ?? 3;
      final reps = ex['reps']?.toString() ?? '10';
      final target = RegExp(r'\d+(\.\d+)?')
              .firstMatch(ex['targetWeight']?.toString() ?? '')
              ?.group(0) ??
          '';
      final firstRep = reps.contains('-')
          ? reps.split('-')[0]
          : reps.replaceAll(RegExp(r'[^0-9]'), '');
      return {
        'name': ex['name']?.toString() ?? '',
        'targetWeight': target,
        'targetSets': sets,
        'targetReps': reps,
        'rest': ex['rest']?.toString() ?? '60s',
        'sets': List.generate(sets, (i) => _blankSet(target, firstRep)),
      };
    }).toList();
  }

  /// Loads the selected date: a saved log if there is one, otherwise the session the schedule suggests.
  Future<void> _loadDay() async {
    final gen = ++_loadGen;
    final plan = context.read<PlanProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;
    _structureEdited = false;
    setState(() => _loadingExercises = true);

    List<dynamic> logs = _allLogs;
    try {
      logs = await ApiService.getLogs(userId);
    } catch (_) {
      // Offline: fall back to whatever was loaded before.
    }
    if (!mounted || gen != _loadGen) return;
    _allLogs = logs;

    Map? existing;
    for (final l in logs) {
      if (l is Map && l['date']?.toString() == _logDate) existing = l;
    }

    final isRest = existing?['rest']?.toString().trim() == 'true';
    final saved = parseLoggedExercises(existing?['exercises']);
    final plannedRaw = existing?['plannedDay']?.toString().trim() ?? '';

    if (isRest) {
      setState(() {
        _rest = true;
        _plannedDay = null;
        _session = 'Rest';
        _exercises = [];
        _loadingExercises = false;
      });
      return;
    }

    if (saved.isNotEmpty) {
      final own = weekdayNames[_date.weekday - 1];
      setState(() {
        _rest = false;
        _plannedDay = plannedRaw.isNotEmpty
            ? plannedRaw
            : (trainingDays(plan.training).contains(own) ? own : null);
        _session = existing?['session']?.toString().trim() ?? '';
        _exercises = saved
            .whereType<Map>()
            .map<Map<String, dynamic>>((ex) {
              final sets = ((ex['sets'] as List?) ?? [])
                  .whereType<Map>()
                  .map<Map<String, dynamic>>(
                    (s) => {
                      'weight': s['weight']?.toString() ?? '',
                      'reps': s['reps']?.toString() ?? '',
                      'done': s['done'] == true,
                    },
                  )
                  .toList();
              return {
                'name': ex['name']?.toString() ?? '',
                // An exercise kept without any logged set comes back as three empty rows.
                'sets': sets.isEmpty ? List.generate(3, (_) => _blankSet('', '')) : sets,
              };
            })
            .toList();
        _loadingExercises = false;
      });
      return;
    }

    final suggestion = suggestedSession(
      training: plan.training,
      date: _date,
      logs: logs,
      challengeStart: _challengeStart,
    );
    if (suggestion != null && plan.training?[suggestion] is Map) {
      _applyDay(suggestion, userId);
    } else {
      setState(() {
        _rest = false;
        _plannedDay = null;
        _session = weekdayNames[_date.weekday - 1];
        _exercises = [];
        _loadingExercises = false;
      });
    }
  }

  /// Switches the day to a plan session and prefills weights from the last time it was done.
  void _applyDay(String day, String userId) {
    final data = context.read<PlanProvider>().training?[day];
    if (data is! Map) return;
    setState(() {
      _rest = false;
      _plannedDay = day;
      _session = data['session']?.toString() ?? day;
      _exercises = _exercisesFromPlan(data);
      _loadingExercises = false;
    });
    _applyLast(userId);
  }

  void _changeDate(DateTime next) {
    final d = dateOnly(next);
    final today = dateOnly(DateTime.now());
    if (d.isAfter(today) || d.isBefore(_earliestDate) || d == _date) return;
    // Flush the pending edit for the day being left; it reads state before its first await.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveNow();
    }
    _skipRest();
    setState(() => _date = d);
    _loadDay();
  }

  Future<bool> _confirmReplace() async {
    if (_doneSets == 0) return true;
    final t = context.read<ThemeProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Replace this day?', style: ftText(t, size: 17, weight: FontWeight.w600)),
        content: Text(
          'You already logged $_doneSets ${_doneSets == 1 ? 'set' : 'sets'} for $_prettyDate. Changing the plan for the day replaces them.',
          style: ftText(t, size: 14, color: t.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _chooseSession(String day) async {
    if (!_rest && _plannedDay == day) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || !await _confirmReplace() || !mounted) return;
    _applyDay(day, userId);
    _saveNow();
  }

  Future<void> _chooseRest() async {
    if (_rest || !await _confirmReplace() || !mounted) return;
    _saveDebounce?.cancel();
    _skipRest();
    setState(() {
      _rest = true;
      _plannedDay = null;
      _session = 'Rest';
      _exercises = [];
    });
    await _saveNow();
    _refreshLogs();
  }

  Future<void> _chooseCustom() async {
    final t = context.read<ThemeProvider>();
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Add workout', style: ftText(t, size: 17, weight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: _maxNameLength,
          style: ftText(t, size: 15),
          decoration: fitTrackInput('e.g. Arms and abs', t).copyWith(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !mounted || !await _confirmReplace() || !mounted) return;
    _skipRest();
    setState(() {
      _rest = false;
      _plannedDay = null;
      _session = title;
      _exercises = [];
    });
  }

  /// Re-reads the logs so the schedule for later days reflects what was just saved.
  Future<void> _refreshLogs() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    try {
      final logs = await ApiService.getLogs(userId);
      if (mounted) setState(() => _allLogs = logs);
    } catch (_) {}
  }

  Future<void> _addExercise() async {
    if (_exercises.length >= _maxExercisesPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That is the most exercises one day can hold')),
      );
      return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.read<ThemeProvider>().surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
      ),
      builder: (_) => const _AddExerciseSheet(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final clean = name.trim();
    if (_exercises.any((e) => e['name'].toString().toLowerCase() == clean.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$clean is already in today\'s list')),
      );
      return;
    }
    _structureEdited = true;
    setState(() {
      if (_session.trim().isEmpty) _session = 'Workout';
      _rest = false;
      _exercises.add({
        'name': clean,
        'rest': '90s',
        'sets': List.generate(3, (_) => _blankSet('', '')),
      });
    });
  }

  void _useInstead(int index, LibraryExercise alt) {
    _structureEdited = true;
    setState(() {
      final ex = _exercises[index];
      ex['name'] = alt.name;
      ex['targetWeight'] = '';
      ex['last'] = '';
      for (final s in ex['sets'] as List) {
        s['weight'] = '';
        s['done'] = false;
      }
      _prefillGen++;
    });
    _saveNow();
  }

  bool _hasLoggedData(Map<String, dynamic> ex) => (ex['sets'] as List).any(
        (s) => s['done'] == true || s['weight'].toString().isNotEmpty,
      );

  Future<bool> _confirmExerciseChange(String title, String body, String action) async {
    final t = context.read<ThemeProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(title, style: ftText(t, size: 17, weight: FontWeight.w600)),
        content: Text(body, style: ftText(t, size: 14, color: t.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeExercise(int index) async {
    final ex = _exercises[index];
    if (_hasLoggedData(ex) &&
        !await _confirmExerciseChange(
          'Remove ${ex['name']}?',
          'The sets you entered for it will be deleted.',
          'Remove',
        )) {
      return;
    }
    if (!mounted) return;
    _structureEdited = true;
    setState(() {
      _exercises.removeAt(index);
      _prefillGen++;
    });
    _saveDebounce?.cancel();
    _saveNow();
  }

  /// Swaps an exercise for whatever was actually done, e.g. a machine press instead of a dumbbell press.
  Future<void> _replaceExercise(int index) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.read<ThemeProvider>().surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.panel)),
      ),
      builder: (_) => const _AddExerciseSheet(title: 'What did you do instead?'),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || !mounted) return;
    final ex = _exercises[index];
    if (clean.toLowerCase() == ex['name'].toString().toLowerCase()) return;
    if (_exercises.any((e) => e['name'].toString().toLowerCase() == clean.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$clean is already in this list')),
      );
      return;
    }
    if (_hasLoggedData(ex) &&
        !await _confirmExerciseChange(
          'Replace ${ex['name']}?',
          'Its entered weights and ticks are cleared, since $clean is a different movement.',
          'Replace',
        )) {
      return;
    }
    if (!mounted) return;
    _structureEdited = true;
    setState(() {
      ex['name'] = clean;
      ex['targetWeight'] = '';
      ex['last'] = '';
      for (final s in ex['sets'] as List) {
        s['weight'] = '';
        s['done'] = false;
      }
      _prefillGen++;
    });
    _saveDebounce?.cancel();
    _saveNow();
    final user = context.read<AuthProvider>().userId;
    if (user != null) _applyLast(user);
  }

  void _openHowTo(int index) {
    final lib = ExerciseLibrary.cached;
    final name = _exercises[index]['name'].toString();
    final ex = lib?.match(name);
    if (lib == null || ex == null) return;
    showExerciseHowTo(
      context,
      ex,
      alternatives: _isToday ? lib.alternatives(ex) : const [],
      onUseInstead: _isToday ? (alt) => _useInstead(index, alt) : null,
    );
  }

  void _toggleDone(int exIndex, int setIndex) {
    setState(() {
      final sets = _exercises[exIndex]['sets'] as List;
      sets[setIndex]['done'] = !(sets[setIndex]['done'] as bool);
    });
    if (_exercises[exIndex]['sets'][setIndex]['done'] == true) {
      _startRest(parseRestSeconds(_exercises[exIndex]['rest']?.toString()));
    }
    _saveDebounce?.cancel();
    _saveNow();
  }

  void _autoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  Future<void> _saveNow() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final dayNumber = _dayNumberFor(_date);

    try {
      final exercisesJson = _rest
          ? '[]'
          : jsonEncode(
              _exercises
                  .where(
                    (e) =>
                        _structureEdited ||
                        (e['sets'] as List).any(
                          (s) => s['weight'].toString().isNotEmpty,
                        ),
                  )
                  .map(
                    (e) => {
                      'name': e['name'],
                      'sets': (e['sets'] as List)
                          .where((s) => s['weight'].toString().isNotEmpty)
                          .map(
                            (s) => {
                              'weight': s['weight'],
                              'reps': s['reps'],
                              'done': s['done'],
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            );

      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _logDate,
        'dayNumber': dayNumber,
        'session': _session,
        'exercises': exercisesJson,
        'plannedDay': _plannedDay ?? '',
        'rest': _rest ? 'true' : 'false',
      });
    } catch (_) {}
  }

  void _finishWorkout() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final dayNumber = _dayNumberFor(_date);

    try {
      final exercisesJson = jsonEncode(
        _exercises
            .map(
              (e) => {
                'name': e['name'],
                'sets': (e['sets'] as List)
                    .map(
                      (s) => {
                        'weight': s['weight'],
                        'reps': s['reps'],
                        'done': s['done'],
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      );

      await ApiService.saveLog({
        'userId': auth.userId,
        'date': _logDate,
        'dayNumber': dayNumber,
        'session': _session,
        'exercises': exercisesJson,
        'notes': '',
        'plannedDay': _plannedDay ?? '',
        'rest': 'false',
      });
      _refreshLogs();

      if (mounted) {
        setState(() {
          _saving = false;
          _showSaved = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSaved = false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (_loadingExercises) return const FtLoader();

    return Stack(
      children: [
        _body(theme),
        if (_restLeft > 0)
          Positioned(
            left: Sp.x5,
            right: Sp.x5,
            bottom: Sp.x4,
            child: _restBar(theme),
          ),
      ],
    );
  }

  Widget _restBar(ThemeProvider theme) {
    final m = _restLeft ~/ 60;
    final sec = (_restLeft % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x2),
      decoration: BoxDecoration(
        color: theme.surface2,
        borderRadius: BorderRadius.circular(Rd.card),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Text('Rest', style: ftText(theme, size: 13, color: theme.textTertiary)),
          const SizedBox(width: Sp.x3),
          Text(
            '$m:$sec',
            style: ftText(theme, size: 20, weight: FontWeight.w600, tabular: true),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _restTotal == 0 ? 0 : _restLeft / _restTotal,
                minHeight: 4,
                backgroundColor: theme.border,
                valueColor: AlwaysStoppedAnimation(theme.accent),
              ),
            ),
          ),
          TextButton(
            onPressed: _skipRest,
            child: Text(
              'Skip',
              style: ftText(theme, size: 14, weight: FontWeight.w500, color: theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBar(ThemeProvider theme) {
    final today = dateOnly(DateTime.now());
    final canBack = _date.isAfter(_earliestDate);
    final canForward = _date.isBefore(today);
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: canBack ? () => _changeDate(_date.subtract(const Duration(days: 1))) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: _earliestDate,
                lastDate: today,
              );
              if (picked != null) _changeDate(picked);
            },
            child: Column(
              children: [
                Text(
                  _isToday ? 'Today' : 'Logging for',
                  style: ftText(theme, size: 12, color: theme.textTertiary),
                ),
                Text(
                  _prettyDate,
                  style: ftText(theme, size: 15, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: canForward ? () => _changeDate(_date.add(const Duration(days: 1))) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _chooser(ThemeProvider theme) {
    final plan = context.watch<PlanProvider>();
    final open = openSessions(training: plan.training, date: _date, logs: _allLogs);
    final options = <String>{?_plannedDay, ...open}.toList()
      ..sort((a, b) => weekdayNames.indexOf(a).compareTo(weekdayNames.indexOf(b)));
    final custom = !_rest && _plannedDay == null && _session.trim().isNotEmpty && _exercises.isNotEmpty;

    String label(String day) {
      final data = plan.training?[day];
      final s = data is Map ? data['session']?.toString().trim() ?? '' : '';
      return s.isEmpty ? day : s;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isToday ? 'What are you doing today?' : 'What did you do?',
          style: ftText(theme, size: 13, color: theme.textTertiary),
        ),
        const SizedBox(height: Sp.x2),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            for (final day in options)
              FtChip(
                label: label(day),
                selected: !_rest && _plannedDay == day,
                onTap: () => _chooseSession(day),
              ),
            FtChip(label: 'Rest', selected: _rest, onTap: _chooseRest),
            FtChip(
              label: custom ? _session : 'Add workout',
              selected: custom,
              onTap: _chooseCustom,
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(ThemeProvider theme) {
    final lib = ExerciseLibrary.cached;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Sp.x5,
        Sp.x3,
        Sp.x5,
        _restLeft > 0 ? 88 : Sp.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateBar(theme),
          const SizedBox(height: Sp.x3),
          _chooser(theme),
          const SizedBox(height: Sp.x5),
          if (_rest) ...[
            FtCard(
              padding: const EdgeInsets.all(Sp.x6),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Icon(Icons.bedtime_outlined, color: theme.textTertiary),
                    const SizedBox(height: Sp.x2),
                    Text('Rest day', style: ftText(theme, size: 16, weight: FontWeight.w500)),
                    const SizedBox(height: Sp.x1),
                    Text(
                      'Your next session moves to the following day. Pick a session above to undo.',
                      textAlign: TextAlign.center,
                      style: ftText(theme, size: 14, color: theme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _session,
                  style: ftText(theme, size: 20, weight: FontWeight.w600),
                ),
              ),
              if (_totalSets > 0)
                Text(
                  '$_doneSets / $_totalSets sets',
                  style: ftText(
                    theme,
                    size: 13,
                    color: theme.textSecondary,
                    tabular: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x4),

          if (_isToday && _exercises.isNotEmpty) ...[
            StretchCard(key: ValueKey('warm-$_session'), plan: warmupFor(_session)),
            const SizedBox(height: Sp.x3),
          ],

          if (_exercises.isEmpty)
            FtCard(
              padding: const EdgeInsets.all(Sp.x6),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      'No exercises yet',
                      style: ftText(theme, size: 16, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      'Pick a session above or add your own exercise.',
                      textAlign: TextAlign.center,
                      style: ftText(theme, size: 14, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

          for (var i = 0; i < _exercises.length; i++) ...[
            _exerciseCard(theme, i, lib),
            const SizedBox(height: Sp.x3),
          ],

          FtButton(label: 'Add exercise', secondary: true, onPressed: _addExercise),
          const SizedBox(height: Sp.x3),

          if (_isToday && _exercises.isNotEmpty) ...[
            StretchCard(key: ValueKey('cool-$_session'), plan: cooldownFor(_session)),
            const SizedBox(height: Sp.x3),
          ],

          AnimatedOpacity(
            opacity: _showSaved ? 1 : 0,
            duration: Motion.fast,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: theme.positive),
                  const SizedBox(width: Sp.x2),
                  Text(
                    'Workout saved',
                    style: ftText(theme, size: 14, color: theme.positive),
                  ),
                ],
              ),
            ),
          ),
          FtButton(
            label: 'Finish workout',
            loading: _saving,
            onPressed: _saving || _exercises.isEmpty ? null : _finishWorkout,
          ),
          ],
          const SizedBox(height: Sp.x6),
        ],
      ),
    );
  }

  Widget _exerciseCard(ThemeProvider theme, int i, ExerciseLibrary? lib) {
    final ex = _exercises[i];
    final sets = ex['sets'] as List;
    final targetReps = ex['targetReps']?.toString() ?? '';
    final rest = ex['rest']?.toString() ?? '';
    final targetWeight = ex['targetWeight']?.toString() ?? '';
    final meta = [
      if (targetReps.isNotEmpty) '$targetReps reps',
      if (targetWeight.isNotEmpty) 'target $targetWeight lb',
      if (rest.isNotEmpty) '$rest rest',
    ].join('  ·  ');

    final headStyle = ftText(theme, size: 12, color: theme.textTertiary);
    final last = ex['last']?.toString() ?? '';
    final hasDemo = lib?.match(ex['name'].toString()) != null;

    return FtCard(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ex['name'].toString(),
                  style: ftText(theme, size: 16, weight: FontWeight.w500),
                ),
              ),
              if (hasDemo)
                IconButton(
                  tooltip: 'How to',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.play_circle_outline, color: theme.textSecondary),
                  onPressed: () => _openHowTo(i),
                ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_horiz, color: theme.textSecondary),
                color: theme.surface2,
                onSelected: (v) => v == 'remove' ? _removeExercise(i) : _replaceExercise(i),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'replace', child: Text('I did a different exercise')),
                  PopupMenuItem(value: 'remove', child: Text('Remove from today')),
                ],
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: Sp.x1),
            Text(
              meta,
              style: ftText(
                theme,
                size: 13,
                color: theme.textTertiary,
                tabular: true,
              ),
            ),
          ],
          if (last.isNotEmpty) ...[
            const SizedBox(height: Sp.x1),
            Text(
              'Last time  $last',
              style: ftText(theme, size: 13, color: theme.textSecondary, tabular: true),
            ),
          ],
          const SizedBox(height: Sp.x4),
          Row(
            children: [
              SizedBox(width: 28, child: Text('Set', style: headStyle)),
              const SizedBox(width: Sp.x3),
              Expanded(child: Text('Weight (lb)', style: headStyle)),
              const SizedBox(width: Sp.x2),
              Expanded(child: Text('Reps', style: headStyle)),
              const SizedBox(width: Sp.x2),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: Sp.x2),
          for (var si = 0; si < sets.length; si++) _setRow(theme, i, si),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                sets.add({'weight': '', 'reps': '', 'done': false});
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: theme.textSecondary),
                    const SizedBox(width: Sp.x1),
                    Text(
                      'Add set',
                      style: ftText(
                        theme,
                        size: 13,
                        weight: FontWeight.w500,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow(ThemeProvider theme, int exIndex, int si) {
    final set = (_exercises[exIndex]['sets'] as List)[si] as Map<String, dynamic>;
    final done = set['done'] as bool;

    final fieldStyle = ftText(
      theme,
      size: 20,
      weight: FontWeight.w500,
      tabular: true,
      color: done ? theme.textSecondary : theme.textPrimary,
    );

    InputDecoration deco() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: theme.surface2,
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Sp.x3,
        vertical: Sp.x3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rd.control),
        borderSide: BorderSide(color: theme.accent),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${si + 1}',
              style: ftText(
                theme,
                size: 16,
                weight: FontWeight.w500,
                tabular: true,
                color: done ? theme.accent : theme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: TextFormField(
              key: ValueKey('w-$exIndex-$si-$_prefillGen'),
              initialValue: set['weight'],
              style: fieldStyle,
              textAlign: TextAlign.center,
              decoration: deco(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                set['weight'] = v;
                _autoSave();
              },
            ),
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: TextFormField(
              initialValue: set['reps'],
              style: fieldStyle,
              textAlign: TextAlign.center,
              decoration: deco(),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                set['reps'] = v;
                _autoSave();
              },
            ),
          ),
          const SizedBox(width: Sp.x2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleDone(exIndex, si),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: FtCheck(done: done, size: 32)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick an exercise from the library or type your own name.
class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet({this.title = 'Add exercise'});
  final String title;

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _controller = TextEditingController();
  List<LibraryExercise> _hits = const [];

  @override
  void initState() {
    super.initState();
    ExerciseLibrary.load().then((_) {
      if (mounted) _search(_controller.text);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    final lib = ExerciseLibrary.cached;
    setState(() => _hits = lib == null ? const [] : lib.search(q.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final typed = _controller.text.trim();
    final exact = _hits.any((e) => e.name.toLowerCase() == typed.toLowerCase());
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.x5,
        Sp.x5,
        Sp.x5,
        MediaQuery.of(context).viewInsets.bottom + Sp.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: ftText(t, size: 18, weight: FontWeight.w600)),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxNameLength,
            style: ftText(t, size: 15),
            decoration: fitTrackInput('Search or type a name', t).copyWith(counterText: ''),
            onChanged: _search,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
            },
          ),
          const SizedBox(height: Sp.x2),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (typed.isNotEmpty && !exact)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.add, color: t.accent),
                    title: Text('Use "$typed"', style: ftText(t, size: 14, weight: FontWeight.w500)),
                    onTap: () => Navigator.pop(context, typed),
                  ),
                for (final e in _hits)
                  ListTile(
                    dense: true,
                    title: Text(e.name, style: ftText(t, size: 14)),
                    subtitle: Text(
                      [if (e.primary.isNotEmpty) e.primary.first, if (e.equipment != 'None') e.equipment].join(' · '),
                      style: ftText(t, size: 12, color: t.textTertiary),
                    ),
                    onTap: () => Navigator.pop(context, e.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
