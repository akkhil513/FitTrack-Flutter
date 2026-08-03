import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 1;
  final int _totalSteps = 6;
  final ScrollController _scrollController = ScrollController();

  // Step 1 — Challenge
  int _challengeDuration = 100;

  // Step 2 — Gender
  String _gender = '';

  // Step 3 — Body stats
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _physiqueController = TextEditingController();
  final _primaryGoalController = TextEditingController();
  final _genderController = TextEditingController();
  final _fatStorageController = TextEditingController();
  final _bulkApproachController = TextEditingController();
  final _trainingLevelController = TextEditingController();
  final _gymAccessController = TextEditingController();
  final _daysPerWeekController = TextEditingController();
  final _sessionDurationController = TextEditingController();
  final _preferredTimeController = TextEditingController();
  final _secondaryGoalController = TextEditingController();
  final _dietTypeController = TextEditingController();
  final _appetiteController = TextEditingController();
  final _proteinTypeController = TextEditingController();
  String _physique = '';
  String _fatStorage = '';

  // Step 4 — Goals (gender-aware)
  String _primaryGoal = '';
  String _secondaryGoal = '';
  String _bulkApproach = '';

  // Step 5 — Training
  String _trainingLevel = '';
  String _gymAccess = '';
  String _daysPerWeek = '4';
  String _sessionDuration = '60 minutes';
  String _preferredTime = 'Evening';
  List<String> _focusAreas = [];

  // Step 6 — Nutrition + Supplements
  String _dietType = '';
  String _appetite = '';
  bool _usesProtein = false;
  String _proteinType = '';
  bool _wantsRecommendation = false;
  List<String> _currentSupplements = [];

  String _error = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _physiqueController.dispose();
    _primaryGoalController.dispose();
    _genderController.dispose();
    _fatStorageController.dispose();
    _bulkApproachController.dispose();
    _trainingLevelController.dispose();
    _gymAccessController.dispose();
    _daysPerWeekController.dispose();
    _sessionDurationController.dispose();
    _preferredTimeController.dispose();
    _secondaryGoalController.dispose();
    _dietTypeController.dispose();
    _appetiteController.dispose();
    _proteinTypeController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < _totalSteps) {
      setState(() {
        _step++;
        _error = '';
      });
      _scrollToTop();
    } else {
      _generatePlan();
    }
  }

  void _back() {
    if (_step > 1)
      setState(() {
        _step--;
        _error = '';
      });
    _scrollToTop();
  }

  bool _validateStep() {
    switch (_step) {
      case 1:
        return true;
      case 2:
        if (_gender.isEmpty) {
          setState(() => _error = 'Please select your gender');
          return false;
        }
      case 3:
        if (_ageController.text.isEmpty || _weightController.text.isEmpty) {
          setState(() => _error = 'Please fill in age and weight');
          return false;
        }
      case 4:
        if (_primaryGoal.isEmpty || _bulkApproach.isEmpty) {
          setState(() => _error = 'Please select your goal and approach');
          return false;
        }
      case 5:
        if (_trainingLevel.isEmpty || _gymAccess.isEmpty) {
          setState(() => _error = 'Please fill in your training details');
          return false;
        }
      case 6:
        if (_dietType.isEmpty) {
          setState(() => _error = 'Please select your diet type');
          return false;
        }
    }
    setState(() => _error = '');
    return true;
  }

  void _generatePlan() async {
    setState(() => _step = 7);

    if (mounted) {
      context.read<UserProvider>().setChallengeDuration(_challengeDuration);
    }

    try {
      await ApiService.updateUser(
        userId: AuthService.userId!,
        challengeDuration: _challengeDuration,
      );
    } catch (e) {
      debugPrint('updateUser failed: $e');
    }

    final payload = {
      'userId': AuthService.userId,
      'challengeDuration': _challengeDuration.toString(),
      'age': _ageController.text,
      'gender': _gender,
      'height': _heightController.text.isEmpty
          ? '5\'7"'
          : _heightController.text,
      'weight': _weightController.text,
      'physique': _physique.isEmpty ? 'Average' : _physique,
      'fatStorage': [_fatStorage.isEmpty ? 'Belly / Midsection' : _fatStorage],
      'primaryGoal': _primaryGoal,
      'secondaryGoal': _secondaryGoal,
      'bulkApproach': _bulkApproach,
      'focusAreas': _focusAreas,
      'trainingLevel': _trainingLevel,
      'gymAccess': _gymAccess,
      'daysPerWeek': _daysPerWeek,
      'sessionDuration': _sessionDuration,
      'preferredTrainTime': _preferredTime,
      'dietType': _dietType,
      'foodPreference': 'No preference',
      'appetite': _appetite.isEmpty ? 'Moderate' : _appetite,
      'supplements': _currentSupplements.isEmpty
          ? ['None']
          : _currentSupplements,
      'injuries': ['No injuries'],
      'sleepHours': '7-8 hours',
      'stressLevel': 'Moderate',
      'coachingStyle': 'Strict',
      'trackingPreference': 'Simple',
      'visualGoals': _focusAreas,
      'usesProteinPowder': _usesProtein,
      'proteinPowderType': _proteinType.isEmpty
          ? 'Whey Concentrate'
          : _proteinType,
      'needsProteinRestock': _wantsRecommendation,
      'wantsProteinRecommendation': _wantsRecommendation,
    };

    if (!mounted) return;
    final planProvider = context.read<PlanProvider>();
    await planProvider.generatePlan(payload);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: _step == 7 ? _buildGenerating(theme) : _buildSteps(theme),
      ),
    );
  }

  // ── GENERATING ───────────────────────────────────────────
  Widget _buildGenerating(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              'BUILDING YOUR PLAN',
              style: TextStyle(
                color: theme.accent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI is analyzing your profile...',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '$_challengeDuration-day $_primaryGoal plan',
              style: TextStyle(
                color: theme.accent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: theme.accent),
            const SizedBox(height: 24),
            Text(
              'This takes about 30-60 seconds',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEPS WRAPPER ────────────────────────────────────────
  Widget _buildSteps(ThemeProvider theme) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _step / _totalSteps,
          backgroundColor: theme.border,
          valueColor: AlwaysStoppedAnimation(theme.accent),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'STEP $_step OF $_totalSteps',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_step == 1) _buildChallenge(theme),
                if (_step == 2) _buildGender(theme),
                if (_step == 3) _buildBodyStats(theme),
                if (_step == 4) _buildGoals(theme),
                if (_step == 5) _buildTraining(theme),
                if (_step == 6) _buildNutrition(theme),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          decoration: BoxDecoration(
            color: theme.background,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _step > 1 ? _back : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '← BACK',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.accentText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _step == _totalSteps ? 'GENERATE MY PLAN 🔥' : 'NEXT →',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
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
  }

  // ── STEP 1: CHALLENGE SELECTION ──────────────────────────
  Widget _buildChallenge(ThemeProvider theme) {
    final challenges = [
      {
        'days': 21,
        'tag': 'QUICK RESET',
        'title': '21-Day Jumpstart',
        'desc': 'Maximum intensity. No sugar. Fast visible results.',
        'icon': '⚡',
        'color': Colors.orange,
      },
      {
        'days': 45,
        'tag': 'TRANSFORMATION',
        'title': '45-Day Body Change',
        'desc': 'Two phases. Fat loss then lean muscle. Real change.',
        'icon': '🔥',
        'color': Colors.red,
      },
      {
        'days': 75,
        'tag': 'SERIOUS COMMIT',
        'title': '75-Day Recomp',
        'desc': 'Three phases. Lose fat. Build muscle. Get strong.',
        'icon': '💪',
        'color': Colors.blue,
      },
      {
        'days': 100,
        'tag': 'FULL CHALLENGE',
        'title': '100-Day Transformation',
        'desc': 'Complete periodized program. Elite level results.',
        'icon': '🏆',
        'color': Colors.green,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE YOUR\nCHALLENGE',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick the commitment level that fits your life right now.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        ...challenges.map((c) {
          final days = c['days'] as int;
          final isSelected = _challengeDuration == days;
          final color = c['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _challengeDuration = days),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.08) : theme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : theme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon + days circle
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.15)
                            : theme.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c['icon'] as String,
                            style: const TextStyle(fontSize: 22),
                          ),
                          Text(
                            '${c['days']}d',
                            style: TextStyle(
                              color: isSelected ? color : theme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c['tag'] as String,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c['title'] as String,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            c['desc'] as String,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── STEP 2: GENDER ───────────────────────────────────────
  Widget _buildGender(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT YOU',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us personalize your plan and questions.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _label('I AM A...', theme),
        Row(
          children: [
            _genderCard('Male', '👨', theme),
            const SizedBox(width: 12),
            _genderCard('Female', '👩', theme),
            const SizedBox(width: 12),
            _genderCard('Other', '🧑', theme),
          ],
        ),
        const SizedBox(height: 12),
        _manualField(
          controller: _genderController,
          hint: 'Or type your gender manually',
          theme: theme,
          onChanged: (value) => setState(() => _gender = value.trim()),
        ),
      ],
    );
  }

  Widget _genderCard(String label, String emoji, ThemeProvider theme) {
    final isSelected = _gender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _gender = label;
          _genderController.text = label;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? theme.accent.withOpacity(0.1) : theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.accent : theme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? theme.accent : theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 3: BODY STATS ───────────────────────────────────
  Widget _buildBodyStats(ThemeProvider theme) {
    final isFemale = _gender == 'Female';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR BODY',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We use this to calculate your exact calorie and protein targets.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),

        _label('AGE', theme),
        _textField(
          _ageController,
          'e.g. 26',
          theme,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('HEIGHT', theme),
                  _textField(
                    _heightController,
                    isFemale ? 'e.g. 5\'4"' : 'e.g. 5\'8"',
                    theme,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('WEIGHT (kg)', theme),
                  _textField(
                    _weightController,
                    isFemale ? 'e.g. 58' : 'e.g. 76',
                    theme,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _label('YOUR CURRENT BODY TYPE', theme),
        _optionColumn(
          isFemale
              ? [
                  'Slim (want to tone and add curves)',
                  'Average (some fat, want to lean out)',
                  'Curvy (want to lose fat and tone)',
                  'Athletic (want to maintain and improve)',
                ]
              : [
                  'Skinny (want to build size)',
                  'Skinny-fat (belly fat, low muscle)',
                  'Average (want to lean out and build)',
                  'Athletic (want to improve performance)',
                  'Overweight (want to lose fat first)',
                ],
          _physique,
          (v) => setState(() {
            _physique = v;
            _physiqueController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _physiqueController,
          style: TextStyle(color: theme.textPrimary),
          onChanged: (value) => setState(() => _physique = value.trim()),
          decoration: InputDecoration(
            hintText: 'Or type your body type manually',
            hintStyle: TextStyle(color: theme.textSecondary),
            filled: true,
            fillColor: theme.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.accent, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _label('WHERE DO YOU STORE MOST FAT?', theme),
        _optionRow(
          isFemale
              ? ['Belly', 'Hips & thighs', 'Arms', 'All over']
              : ['Belly / Midsection', 'Chest', 'Love handles', 'All over'],
          _fatStorage,
          (v) => setState(() {
            _fatStorage = v;
            _fatStorageController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _fatStorageController,
          hint: 'Or type fat storage area manually',
          theme: theme,
          onChanged: (value) => setState(() => _fatStorage = value.trim()),
        ),
      ],
    );
  }

  // ── STEP 4: GOALS (gender-aware) ─────────────────────────
  Widget _buildGoals(ThemeProvider theme) {
    final isFemale = _gender == 'Female';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR GOALS',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Be honest — the AI builds your plan around this.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),

        _label('MAIN GOAL', theme),
        _optionColumn(
          isFemale
              ? [
                  'Lose fat and tone up',
                  'Build lean muscle and curves',
                  'Improve overall fitness and health',
                  'Build strength and confidence',
                  'Body recomposition (lose fat + gain muscle)',
                ]
              : [
                  'Build visible muscle (aesthetics)',
                  'Lose belly fat and get lean',
                  'Get stronger and bigger',
                  'Body recomposition (lose fat + gain muscle)',
                  'Improve overall fitness and health',
                ],
          _primaryGoal,
          (v) => setState(() {
            _primaryGoal = v;
            _primaryGoalController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _primaryGoalController,
          style: TextStyle(color: theme.textPrimary),
          onChanged: (value) => setState(() => _primaryGoal = value.trim()),
          decoration: InputDecoration(
            hintText: 'Or type your goal manually',
            hintStyle: TextStyle(color: theme.textSecondary),
            filled: true,
            fillColor: theme.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.accent, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _label('APPROACH', theme),
        _optionColumn(
          isFemale
              ? [
                  'Lose fat (calorie deficit)',
                  'Tone and maintain',
                  'Slight surplus (build muscle slowly)',
                  'Recomp (maintain weight, change body)',
                ]
              : [
                  'Cut (lose fat, maintain muscle)',
                  'Lean bulk (slow muscle gain)',
                  'Moderate bulk (faster size)',
                  'Recomp (maintain weight, change shape)',
                ],
          _bulkApproach,
          (v) => setState(() {
            _bulkApproach = v;
            _bulkApproachController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _bulkApproachController,
          hint: 'Or type your approach manually',
          theme: theme,
          onChanged: (value) => setState(() => _bulkApproach = value.trim()),
        ),
        const SizedBox(height: 20),

        _label(
          isFemale
              ? 'WHICH AREAS DO YOU WANT TO FOCUS ON?'
              : 'VISUAL GOALS (select all that apply)',
          theme,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              (isFemale
                      ? [
                          'Flat stomach',
                          'Toned arms',
                          'Lifted glutes',
                          'Lean legs',
                          'Defined back',
                          'Toned shoulders',
                        ]
                      : [
                          'Six pack / Core',
                          'Bigger arms',
                          'Broader shoulders',
                          'Bigger chest',
                          'Wider back (V-taper)',
                          'Bigger legs',
                        ])
                  .map((area) {
                    final isSelected = _focusAreas.contains(area);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _focusAreas.remove(area);
                        } else {
                          _focusAreas.add(area);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.accent.withOpacity(0.15)
                              : theme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? theme.accent : theme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          area,
                          style: TextStyle(
                            color: isSelected
                                ? theme.accent
                                : theme.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
        ),
      ],
    );
  }

  // ── STEP 5: TRAINING ─────────────────────────────────────
  Widget _buildTraining(ThemeProvider theme) {
    final isFemale = _gender == 'Female';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR TRAINING',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This determines the structure and intensity of your program.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),

        _label('EXPERIENCE LEVEL', theme),
        _optionColumn(
          [
            'Complete beginner (never trained seriously)',
            'Beginner (under 6 months consistent)',
            'Intermediate (6 months - 2 years)',
            'Advanced (2+ years consistent training)',
          ],
          _trainingLevel,
          (v) => setState(() {
            _trainingLevel = v;
            _trainingLevelController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _trainingLevelController,
          hint: 'Or type your experience level manually',
          theme: theme,
          onChanged: (value) => setState(() => _trainingLevel = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('GYM ACCESS', theme),
        _optionColumn(
          [
            'Full gym (barbells, dumbbells, cables, machines)',
            'Decent gym (dumbbells + machines, no barbell)',
            'Home gym (dumbbells only)',
            'Bodyweight only (no equipment)',
          ],
          _gymAccess,
          (v) => setState(() {
            _gymAccess = v;
            _gymAccessController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _gymAccessController,
          hint: 'Or type your gym access manually',
          theme: theme,
          onChanged: (value) => setState(() => _gymAccess = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('HOW MANY DAYS PER WEEK?', theme),
        _optionRow(
          ['3', '4', '5', '6'],
          _daysPerWeek,
          (v) => setState(() {
            _daysPerWeek = v;
            _daysPerWeekController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _daysPerWeekController,
          hint: 'Or type days per week manually',
          theme: theme,
          onChanged: (value) => setState(() => _daysPerWeek = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('SESSION LENGTH', theme),
        _optionRow(
          ['45 min', '60 min', '75 min', '90+ min'],
          _sessionDuration,
          (v) => setState(() {
            _sessionDuration = v;
            _sessionDurationController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _sessionDurationController,
          hint: 'Or type session length manually',
          theme: theme,
          onChanged: (value) => setState(() => _sessionDuration = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('PREFERRED TRAINING TIME', theme),
        _optionRow(
          ['Early AM', 'Morning', 'Afternoon', 'Evening'],
          _preferredTime,
          (v) => setState(() {
            _preferredTime = v;
            _preferredTimeController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _preferredTimeController,
          hint: 'Or type preferred training time manually',
          theme: theme,
          onChanged: (value) => setState(() => _preferredTime = value.trim()),
        ),

        if (isFemale) ...[
          const SizedBox(height: 20),
          _label('TRAINING EMPHASIS', theme),
          _optionColumn(
            [
              'Full body balanced',
              'Glute and leg focused',
              'Upper body toning focus',
              'Core and cardio focus',
            ],
            _secondaryGoal,
            (v) => setState(() {
              _secondaryGoal = v;
              _secondaryGoalController.text = v;
            }),
            theme,
          ),
          const SizedBox(height: 10),
          _manualField(
            controller: _secondaryGoalController,
            hint: 'Or type your training emphasis manually',
            theme: theme,
            onChanged: (value) => setState(() => _secondaryGoal = value.trim()),
          ),
        ],
      ],
    );
  }

  // ── STEP 6: NUTRITION + SUPPLEMENTS ─────────────────────
  Widget _buildNutrition(ThemeProvider theme) {
    final supplements = [
      'Whey Protein',
      'Creatine',
      'Fish Oil / Omega-3',
      'Vitamin D3',
      'Magnesium',
      'Multivitamin',
      'Pre-workout',
      'BCAA',
      'None',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NUTRITION &\nSUPPLEMENTS',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us set your calorie targets and supplement plan.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),

        _label('DIET TYPE', theme),
        _optionColumn(
          [
            'Non-vegetarian (eat everything)',
            'Vegetarian (no meat, eat eggs/dairy)',
            'Vegan (plant-based only)',
            'Eggetarian (no meat, eat eggs)',
          ],
          _dietType,
          (v) => setState(() {
            _dietType = v;
            _dietTypeController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _dietTypeController,
          hint: 'Or type your diet type manually',
          theme: theme,
          onChanged: (value) => setState(() => _dietType = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('HOW IS YOUR APPETITE?', theme),
        _optionColumn(
          [
            'Small — I struggle to eat enough',
            'Moderate — I eat normal amounts',
            'Good — I eat well regularly',
            'Very high — I\'m always hungry',
          ],
          _appetite,
          (v) => setState(() {
            _appetite = v;
            _appetiteController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: 10),
        _manualField(
          controller: _appetiteController,
          hint: 'Or type your appetite manually',
          theme: theme,
          onChanged: (value) => setState(() => _appetite = value.trim()),
        ),
        const SizedBox(height: 20),

        _label('SUPPLEMENTS YOU CURRENTLY TAKE', theme),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: supplements.map((s) {
            final isSelected = _currentSupplements.contains(s);
            return GestureDetector(
              onTap: () => setState(() {
                if (s == 'None') {
                  _currentSupplements.clear();
                  _currentSupplements.add('None');
                } else {
                  _currentSupplements.remove('None');
                  if (isSelected) {
                    _currentSupplements.remove(s);
                  } else {
                    _currentSupplements.add(s);
                  }
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.accent.withOpacity(0.15)
                      : theme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? theme.accent : theme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: isSelected ? theme.accent : theme.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _label('DO YOU USE PROTEIN POWDER?', theme),
        _optionRow(
          ['Yes', 'No'],
          _usesProtein ? 'Yes' : 'No',
          (v) => setState(() => _usesProtein = v == 'Yes'),
          theme,
        ),

        if (_usesProtein) ...[
          const SizedBox(height: 16),
          _label('WHICH TYPE?', theme),
          _optionColumn(
            [
              'Whey Concentrate',
              'Whey Isolate',
              'Casein (slow release)',
              'Plant-based',
              'Not sure',
            ],
            _proteinType,
            (v) => setState(() {
              _proteinType = v;
              _proteinTypeController.text = v;
            }),
            theme,
          ),
          const SizedBox(height: 10),
          _manualField(
            controller: _proteinTypeController,
            hint: 'Or type your protein type manually',
            theme: theme,
            onChanged: (value) => setState(() => _proteinType = value.trim()),
          ),
        ],
        const SizedBox(height: 16),

        _label('WANT A PROTEIN POWDER RECOMMENDATION?', theme),
        _optionRow(
          ['Yes', 'No'],
          _wantsRecommendation ? 'Yes' : 'No',
          (v) => setState(() => _wantsRecommendation = v == 'Yes'),
          theme,
        ),
      ],
    );
  }

  // ── SHARED HELPERS ───────────────────────────────────────

  Widget _label(String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint,
    ThemeProvider theme, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textSecondary),
        filled: true,
        fillColor: theme.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.accent, width: 2),
        ),
      ),
    );
  }

  Widget _manualField({
    required TextEditingController controller,
    required String hint,
    required ThemeProvider theme,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textPrimary),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textSecondary),
        filled: true,
        fillColor: theme.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.accent, width: 2),
        ),
      ),
    );
  }

  Widget _optionRow(
    List<String> options,
    String selected,
    Function(String) onSelect,
    ThemeProvider theme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = selected == o;
        return GestureDetector(
          onTap: () => onSelect(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accent.withOpacity(0.15)
                  : theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? theme.accent : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              o,
              style: TextStyle(
                color: isSelected ? theme.accent : theme.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _optionColumn(
    List<String> options,
    String selected,
    Function(String) onSelect,
    ThemeProvider theme,
  ) {
    return Column(
      children: options.map((o) {
        final isSelected = selected == o;
        return GestureDetector(
          onTap: () => onSelect(o),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? theme.accent.withOpacity(0.1) : theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? theme.accent : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    o,
                    style: TextStyle(
                      color: isSelected ? theme.accent : theme.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.accent, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
