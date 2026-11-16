import 'package:fittrack/services/nutrition_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads calories and protein from plan text', () {
    final t = NutritionTargets.fromPlanText(
      'Target: 2,400 kcal/day (Lean Bulk / Recomp).\n'
      'Protein: 160g/day (2.2g/kg).\nCarbs: 260g/day.',
    );
    expect(t.calories, 2400);
    expect(t.protein, 160);
  });

  test('reads protein written before the number', () {
    final t = NutritionTargets.fromPlanText('Eat 180 g of protein daily. 2800 calories.');
    expect(t.protein, 180);
    expect(t.calories, 2800);
  });

  test('returns nulls when there is nothing to read', () {
    expect(NutritionTargets.fromPlanText(null).calories, isNull);
    expect(NutritionTargets.fromPlanText('Eat well.').protein, isNull);
  });
}
