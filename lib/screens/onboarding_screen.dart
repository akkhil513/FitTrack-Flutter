import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plan_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';
import 'dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 1;
  final int _totalSteps = 5;

  // Step 1 — Body Stats
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = '';

  // Step 2 — Goals
  String _primaryGoal = '';
  String _bulkApproach = '';

  // Step 3 — Training
  String _trainingLevel = '';
  String _gymAccess = '';
  String _daysPerWeek = '5';
  String _sessionDuration = '60 minutes';

  // Step 4 — Nutrition
  String _dietType = '';
  String _appetite = '';

  // Step 5 — Supplements
  bool _usesProtein = false;
  String _proteinType = '';
  bool _wantsRecommendation = false;

  String _error = '';

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < _totalSteps) {
      setState(() {
        _step++;
        _error = '';
      });
    } else {
      _generatePlan();
    }
  }

  void _back() {
    if (_step > 1) setState(() => _step--);
  }

  bool _validateStep() {
    switch (_step) {
      case 1:
        if (_ageController.text.isEmpty ||
            _weightController.text.isEmpty ||
            _gender.isEmpty) {
          setState(() => _error = 'Please fill in all fields');
          return false;
        }
      case 2:
        if (_primaryGoal.isEmpty || _bulkApproach.isEmpty) {
          setState(() => _error = 'Please select your goals');
          return false;
        }
      case 3:
        if (_trainingLevel.isEmpty || _gymAccess.isEmpty) {
          setState(() => _error = 'Please fill in training info');
          return false;
        }
      case 4:
        if (_dietType.isEmpty) {
          setState(() => _error = 'Please select diet type');
          return false;
        }
    }
    setState(() => _error = '');
    return true;
  }

  void _generatePlan() async {
    setState(() => _step = 6);

    final payload = {
      'userId': AuthService.userId,
      'age': _ageController.text,
      'gender': _gender,
      'height': _heightController.text.isEmpty
          ? '5\'8"'
          : _heightController.text,
      'weight': _weightController.text,
      'physique': 'Average',
      'fatStorage': ['Belly / Midsection'],
      'primaryGoal': _primaryGoal,
      'bulkApproach': _bulkApproach,
      'trainingLevel': _trainingLevel,
      'gymAccess': _gymAccess,
      'daysPerWeek': _daysPerWeek,
      'sessionDuration': _sessionDuration,
      'dietType': _dietType,
      'foodPreference': 'No preference',
      'appetite': _appetite.isEmpty ? 'Moderate' : _appetite,
      'supplements': ['Whey Protein', 'Creatine'],
      'injuries': ['No injuries'],
      'sleepHours': '7-8 hours',
      'stressLevel': 'Moderate',
      'coachingStyle': 'Strict',
      'trackingPreference': 'Simple meal structure',
      'preferredTrainTime': 'Evening',
      'visualGoals': ['Broader shoulders', 'Bigger arms'],
      'usesProteinPowder': _usesProtein,
      'proteinPowderType': _proteinType.isEmpty
          ? 'Whey Concentrate'
          : _proteinType,
      'needsProteinRestock': _wantsRecommendation,
      'wantsProteinRecommendation': _wantsRecommendation,
    };

    final planProvider = context.read<PlanProvider>();
    await planProvider.generatePlan(payload);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      body: AppBackground(
        theme: theme,
        motifs: const [
          Icons.self_improvement,
          Icons.directions_walk,
          Icons.monitor_heart,
        ],
        child: SafeArea(
          child: _step == 6 ? _buildGenerating(theme) : _buildSteps(theme),
        ),
      ),
    );
  }

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
              'Claude AI is analyzing your profile...',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: theme.accent),
            const SizedBox(height: 24),
            Text(
              'This usually takes 30-60 seconds',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps(ThemeProvider theme) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _step / _totalSteps,
          backgroundColor: theme.border,
          valueColor: AlwaysStoppedAnimation(theme.accent),
          minHeight: 4,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'FITTRACK · SETUP',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'STEP $_step OF $_totalSteps',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // Step content
                if (_step == 1) _buildStep1(theme),
                if (_step == 2) _buildStep2(theme),
                if (_step == 3) _buildStep3(theme),
                if (_step == 4) _buildStep4(theme),
                if (_step == 5) _buildStep5(theme),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 32),

                // Navigation buttons
                Row(
                  children: [
                    if (_step > 1) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _back,
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
                    ],
                    Expanded(
                      flex: 2,
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
                          _step == _totalSteps
                              ? 'GENERATE MY PLAN 🔥'
                              : 'NEXT →',
                          style: const TextStyle(
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
        ),
      ],
    );
  }

  // ── STEP 1 — Body Stats ──────────────────────
  Widget _buildStep1(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR BODY STATS',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _label('AGE', theme),
        _textField(
          _ageController,
          'e.g. 25',
          theme,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        _label('GENDER', theme),
        _optionRow(
          ['Male', 'Female', 'Other'],
          _gender,
          (v) => setState(() => _gender = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('HEIGHT (optional)', theme),
        _textField(_heightController, 'e.g. 5\'8"', theme),
        const SizedBox(height: 16),

        _label('WEIGHT (kg)', theme),
        _textField(
          _weightController,
          'e.g. 75',
          theme,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ── STEP 2 — Goals ──────────────────────────
  Widget _buildStep2(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR GOALS',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _label('PRIMARY GOAL', theme),
        _optionColumn(
          [
            'Build visible muscle (aesthetics)',
            'Lose fat and tone up',
            'Get stronger and bigger',
            'Overall fitness and health',
            'Body recomposition',
          ],
          _primaryGoal,
          (v) => setState(() => _primaryGoal = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('APPROACH', theme),
        _optionColumn(
          ['Cut / Lose fat', 'Lean bulk', 'Moderate bulk', 'Maintain'],
          _bulkApproach,
          (v) => setState(() => _bulkApproach = v),
          theme,
        ),
      ],
    );
  }

  // ── STEP 3 — Training ───────────────────────
  Widget _buildStep3(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAINING INFO',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _label('EXPERIENCE LEVEL', theme),
        _optionColumn(
          [
            'Complete beginner (under 6 months)',
            'Beginner (6-12 months)',
            'Intermediate (1-3 years)',
            'Advanced (3+ years)',
          ],
          _trainingLevel,
          (v) => setState(() => _trainingLevel = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('GYM ACCESS', theme),
        _optionColumn(
          [
            'Full gym (barbells, dumbbells, cables)',
            'Decent gym (no barbell)',
            'Home gym (dumbbells only)',
            'Bodyweight only',
          ],
          _gymAccess,
          (v) => setState(() => _gymAccess = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('DAYS PER WEEK', theme),
        _optionRow(
          ['3', '4', '5', '6'],
          _daysPerWeek,
          (v) => setState(() => _daysPerWeek = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('SESSION DURATION', theme),
        _optionColumn(
          ['45 minutes', '60 minutes', '75-90 minutes', '2+ hours'],
          _sessionDuration,
          (v) => setState(() => _sessionDuration = v),
          theme,
        ),
      ],
    );
  }

  // ── STEP 4 — Nutrition ──────────────────────
  Widget _buildStep4(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NUTRITION',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _label('DIET TYPE', theme),
        _optionColumn(
          [
            'Non-vegetarian (eat everything)',
            'Vegetarian (no meat)',
            'Vegan',
            'Eggetarian',
          ],
          _dietType,
          (v) => setState(() => _dietType = v),
          theme,
        ),
        const SizedBox(height: 16),

        _label('APPETITE', theme),
        _optionColumn(
          [
            'Small (struggle to eat enough)',
            'Moderate',
            'Good appetite',
            'Very high appetite',
          ],
          _appetite,
          (v) => setState(() => _appetite = v),
          theme,
        ),
      ],
    );
  }

  // ── STEP 5 — Supplements ────────────────────
  Widget _buildStep5(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUPPLEMENTS',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _label('DO YOU USE PROTEIN POWDER?', theme),
        _optionRow(
          ['Yes', 'No'],
          _usesProtein ? 'Yes' : 'No',
          (v) => setState(() => _usesProtein = v == 'Yes'),
          theme,
        ),
        const SizedBox(height: 16),

        if (_usesProtein) ...[
          _label('WHICH TYPE?', theme),
          _optionColumn(
            [
              'Whey Concentrate',
              'Whey Isolate',
              'Casein',
              'Plant-based',
              'Not sure',
            ],
            _proteinType,
            (v) => setState(() => _proteinType = v),
            theme,
          ),
          const SizedBox(height: 16),
        ],

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

  // ── Shared Widgets ───────────────────────────

  Widget _label(String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          letterSpacing: 2,
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
          borderSide: BorderSide(color: theme.accent),
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
      children: options
          .map(
            (o) => GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected == o ? theme.accent : theme.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == o ? theme.accent : theme.border,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: selected == o ? theme.accentText : theme.textPrimary,
                    fontSize: 13,
                    fontWeight: selected == o
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _optionColumn(
    List<String> options,
    String selected,
    Function(String) onSelect,
    ThemeProvider theme,
  ) {
    return Column(
      children: options
          .map(
            (o) => GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected == o ? theme.accent : theme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == o ? theme.accent : theme.border,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: selected == o ? theme.accentText : theme.textPrimary,
                    fontSize: 13,
                    fontWeight: selected == o
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
