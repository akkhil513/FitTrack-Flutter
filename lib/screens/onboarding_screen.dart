import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/tokens.dart';
import '../widgets/input_decoration.dart';
import '../widgets/ui.dart';
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
  final List<String> _focusAreas = [];

  // Step 6 — Nutrition + Supplements
  String _dietType = '';
  String _appetite = '';
  bool _usesProtein = false;
  String _proteinType = '';
  bool _wantsRecommendation = false;
  final List<String> _currentSupplements = [];

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
    if (_step > 1) {
      setState(() {
        _step--;
        _error = '';
      });
      _scrollToTop();
    }
  }

  bool _validateStep() {
    switch (_step) {
      case 1:
        return true;
      case 2:
        if (_gender.isEmpty) {
          setState(() => _error = 'Select your gender');
          return false;
        }
      case 3:
        if (_ageController.text.isEmpty || _weightController.text.isEmpty) {
          setState(() => _error = 'Enter your age and weight');
          return false;
        }
      case 4:
        if (_primaryGoal.isEmpty || _bulkApproach.isEmpty) {
          setState(() => _error = 'Select your goal and approach');
          return false;
        }
      case 5:
        if (_trainingLevel.isEmpty || _gymAccess.isEmpty) {
          setState(() => _error = 'Select your experience level and gym access');
          return false;
        }
      case 6:
        if (_dietType.isEmpty) {
          setState(() => _error = 'Select your diet type');
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
      final u = context.read<UserProvider>();
      await ApiService.updateUser(
        userId: AuthService.userId!,
        challengeDuration: _challengeDuration,
        firstName: u.firstName,
        lastName: u.lastName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your challenge length. Set it in Profile.'),
          ),
        );
      }
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
        padding: const EdgeInsets.all(Sp.x8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FtLoader(),
            const SizedBox(height: Sp.x6),
            Text(
              'Building your plan',
              style: ftText(theme, size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: Sp.x2),
            Text(
              '$_challengeDuration days  ·  $_primaryGoal',
              textAlign: TextAlign.center,
              style: ftText(theme, size: 14, color: theme.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'This usually takes under a minute.',
              style: ftText(theme, size: 13, color: theme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEPS WRAPPER ────────────────────────────────────────
  Widget _buildSteps(ThemeProvider theme) {
    final Widget stepBody;
    switch (_step) {
      case 1:
        stepBody = _buildChallenge(theme);
      case 2:
        stepBody = _buildGender(theme);
      case 3:
        stepBody = _buildBodyStats(theme);
      case 4:
        stepBody = _buildGoals(theme);
      case 5:
        stepBody = _buildTraining(theme);
      default:
        stepBody = _buildNutrition(theme);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x4, Sp.x6, 0),
          child: Row(
            children: [
              for (var i = 1; i <= _totalSteps; i++) ...[
                if (i > 1) const SizedBox(width: Sp.x1),
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.ease,
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _step ? theme.accent : theme.surface2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(Sp.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $_step of $_totalSteps',
                  style: ftText(
                    theme,
                    size: 13,
                    color: theme.textTertiary,
                    tabular: true,
                  ),
                ),
                const SizedBox(height: Sp.x3),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_step),
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.base,
                  curve: Motion.ease,
                  builder: (context, v, child) =>
                      Opacity(opacity: v, child: child),
                  child: stepBody,
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: Sp.x4),
                  Text(
                    _error,
                    style: ftText(theme, size: 13, color: theme.negative),
                  ),
                ],
                const SizedBox(height: Sp.x6),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x3, Sp.x6, Sp.x4),
          decoration: BoxDecoration(
            color: theme.background,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FtButton(
                  label: 'Back',
                  secondary: true,
                  onPressed: _step > 1 ? _back : null,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                flex: 2,
                child: FtButton(
                  label: _step == _totalSteps ? 'Generate plan' : 'Continue',
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(ThemeProvider theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ftText(theme, size: 28, weight: FontWeight.w600)),
        const SizedBox(height: Sp.x2),
        Text(
          subtitle,
          style: ftText(theme, size: 14, color: theme.textSecondary),
        ),
        const SizedBox(height: Sp.x8),
      ],
    );
  }

  // ── STEP 1: CHALLENGE SELECTION ──────────────────────────
  Widget _buildChallenge(ThemeProvider theme) {
    const challenges = [
      (days: 21, title: 'Jumpstart', desc: 'High intensity over a short window. No added sugar.'),
      (days: 45, title: 'Body change', desc: 'Two phases: fat loss first, then lean muscle.'),
      (days: 75, title: 'Recomp', desc: 'Three phases: fat loss, muscle gain, strength.'),
      (days: 100, title: 'Transformation', desc: 'The full periodized program.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          theme,
          'Choose your challenge',
          'Pick the length that fits your life right now.',
        ),
        for (final c in challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.x3),
            child: FtCard(
              selected: _challengeDuration == c.days,
              onTap: () => setState(() => _challengeDuration = c.days),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.days}',
                          style: ftText(
                            theme,
                            size: 28,
                            weight: FontWeight.w600,
                            tabular: true,
                          ),
                        ),
                        Text(
                          'days',
                          style: ftText(
                            theme,
                            size: 12,
                            color: theme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: ftText(
                            theme,
                            size: 15,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: Sp.x1),
                        Text(
                          c.desc,
                          style: ftText(
                            theme,
                            size: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  AnimatedOpacity(
                    opacity: _challengeDuration == c.days ? 1 : 0,
                    duration: Motion.fast,
                    child: Icon(Icons.check, size: 16, color: theme.accent),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── STEP 2: GENDER ───────────────────────────────────────
  Widget _buildGender(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          theme,
          'About you',
          'This shapes the questions and your targets.',
        ),
        _label('Gender', theme),
        Row(
          children: [
            _genderCard('Male', theme),
            const SizedBox(width: Sp.x2),
            _genderCard('Female', theme),
            const SizedBox(width: Sp.x2),
            _genderCard('Other', theme),
          ],
        ),
        const SizedBox(height: Sp.x3),
        _manualField(
          controller: _genderController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _gender = value.trim()),
        ),
      ],
    );
  }

  Widget _genderCard(String label, ThemeProvider theme) {
    return Expanded(
      child: FtCard(
        selected: _gender == label,
        onTap: () => setState(() {
          _gender = label;
          _genderController.text = label;
        }),
        padding: const EdgeInsets.symmetric(vertical: Sp.x4),
        child: Center(
          child: Text(label, style: ftText(theme, size: 14, weight: FontWeight.w500)),
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
        _title(
          theme,
          'Your body',
          'Used to calculate your calorie and protein targets.',
        ),
        _label('Age', theme),
        _textField(_ageController, 'e.g. 26', theme,
            keyboardType: TextInputType.number),
        const SizedBox(height: Sp.x4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Height', theme),
                  _textField(
                    _heightController,
                    isFemale ? 'e.g. 5\'4"' : 'e.g. 5\'8"',
                    theme,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Weight (kg)', theme),
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
        const SizedBox(height: Sp.x6),

        _label('Current body type', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _physiqueController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _physique = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Where you store most fat', theme),
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
        const SizedBox(height: Sp.x3),
        _manualField(
          controller: _fatStorageController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _fatStorage = value.trim()),
        ),
      ],
    );
  }

  // ── STEP 4: GOALS (gender-aware) ─────────────────────────
  Widget _buildGoals(ThemeProvider theme) {
    final isFemale = _gender == 'Female';
    final areas = isFemale
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
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          theme,
          'Your goals',
          'Your plan is built around these answers.',
        ),
        _label('Main goal', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _primaryGoalController,
          hint: 'Or describe your goal',
          theme: theme,
          onChanged: (value) => setState(() => _primaryGoal = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Approach', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _bulkApproachController,
          hint: 'Or describe your approach',
          theme: theme,
          onChanged: (value) => setState(() => _bulkApproach = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label(
          isFemale
              ? 'Areas to focus on'
              : 'Visual goals (select all that apply)',
          theme,
        ),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            for (final area in areas)
              FtChip(
                label: area,
                selected: _focusAreas.contains(area),
                onTap: () => setState(() {
                  if (_focusAreas.contains(area)) {
                    _focusAreas.remove(area);
                  } else {
                    _focusAreas.add(area);
                  }
                }),
              ),
          ],
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
        _title(
          theme,
          'Your training',
          'Sets the structure and intensity of the program.',
        ),
        _label('Experience level', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _trainingLevelController,
          hint: 'Or describe your experience',
          theme: theme,
          onChanged: (value) => setState(() => _trainingLevel = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Gym access', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _gymAccessController,
          hint: 'Or describe your setup',
          theme: theme,
          onChanged: (value) => setState(() => _gymAccess = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Days per week', theme),
        _optionRow(
          ['3', '4', '5', '6'],
          _daysPerWeek,
          (v) => setState(() {
            _daysPerWeek = v;
            _daysPerWeekController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: Sp.x3),
        _manualField(
          controller: _daysPerWeekController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _daysPerWeek = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Session length', theme),
        _optionRow(
          ['45 min', '60 min', '75 min', '90+ min'],
          _sessionDuration,
          (v) => setState(() {
            _sessionDuration = v;
            _sessionDurationController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: Sp.x3),
        _manualField(
          controller: _sessionDurationController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _sessionDuration = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Preferred training time', theme),
        _optionRow(
          ['Early AM', 'Morning', 'Afternoon', 'Evening'],
          _preferredTime,
          (v) => setState(() {
            _preferredTime = v;
            _preferredTimeController.text = v;
          }),
          theme,
        ),
        const SizedBox(height: Sp.x3),
        _manualField(
          controller: _preferredTimeController,
          hint: 'Or type your own',
          theme: theme,
          onChanged: (value) => setState(() => _preferredTime = value.trim()),
        ),

        if (isFemale) ...[
          const SizedBox(height: Sp.x6),
          _label('Training emphasis', theme),
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
          const SizedBox(height: Sp.x1),
          _manualField(
            controller: _secondaryGoalController,
            hint: 'Or describe your emphasis',
            theme: theme,
            onChanged: (value) => setState(() => _secondaryGoal = value.trim()),
          ),
        ],
      ],
    );
  }

  // ── STEP 6: NUTRITION + SUPPLEMENTS ─────────────────────
  Widget _buildNutrition(ThemeProvider theme) {
    const supplements = [
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
        _title(
          theme,
          'Nutrition and supplements',
          'Sets your calorie targets and supplement plan.',
        ),
        _label('Diet type', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _dietTypeController,
          hint: 'Or describe your diet',
          theme: theme,
          onChanged: (value) => setState(() => _dietType = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Appetite', theme),
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
        const SizedBox(height: Sp.x1),
        _manualField(
          controller: _appetiteController,
          hint: 'Or describe your appetite',
          theme: theme,
          onChanged: (value) => setState(() => _appetite = value.trim()),
        ),
        const SizedBox(height: Sp.x6),

        _label('Supplements you take now', theme),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            for (final s in supplements)
              FtChip(
                label: s,
                selected: _currentSupplements.contains(s),
                onTap: () => setState(() {
                  if (s == 'None') {
                    _currentSupplements
                      ..clear()
                      ..add('None');
                  } else {
                    _currentSupplements.remove('None');
                    if (_currentSupplements.contains(s)) {
                      _currentSupplements.remove(s);
                    } else {
                      _currentSupplements.add(s);
                    }
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: Sp.x6),

        _label('Do you use protein powder?', theme),
        _optionRow(
          ['Yes', 'No'],
          _usesProtein ? 'Yes' : 'No',
          (v) => setState(() => _usesProtein = v == 'Yes'),
          theme,
        ),

        if (_usesProtein) ...[
          const SizedBox(height: Sp.x6),
          _label('Which type?', theme),
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
          const SizedBox(height: Sp.x1),
          _manualField(
            controller: _proteinTypeController,
            hint: 'Or type your own',
            theme: theme,
            onChanged: (value) => setState(() => _proteinType = value.trim()),
          ),
        ],
        const SizedBox(height: Sp.x6),

        _label('Want a protein powder recommendation?', theme),
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

  Widget _label(String text, ThemeProvider theme) => FtLabel(text);

  Widget _textField(
    TextEditingController controller,
    String hint,
    ThemeProvider theme, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: ftText(theme, size: 15),
      decoration: fitTrackInput(hint, theme),
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
      style: ftText(theme, size: 15),
      onChanged: onChanged,
      decoration: fitTrackInput(hint, theme),
    );
  }

  Widget _optionRow(
    List<String> options,
    String selected,
    Function(String) onSelect,
    ThemeProvider theme,
  ) {
    return Wrap(
      spacing: Sp.x2,
      runSpacing: Sp.x2,
      children: [
        for (final o in options)
          FtChip(
            label: o,
            selected: selected == o,
            onTap: () => onSelect(o),
          ),
      ],
    );
  }

  Widget _optionColumn(
    List<String> options,
    String selected,
    Function(String) onSelect,
    ThemeProvider theme,
  ) {
    return Column(
      children: [
        for (final o in options)
          FtChoice(
            label: o,
            selected: selected == o,
            onTap: () => onSelect(o),
          ),
      ],
    );
  }
}
