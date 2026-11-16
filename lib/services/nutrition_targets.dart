/// Daily calorie and protein targets read from the plan's free-text nutrition
/// section (for example "Target: 2,400 kcal/day ... Protein: 160g/day").
class NutritionTargets {
  const NutritionTargets({this.calories, this.protein});

  final int? calories;
  final int? protein;

  static NutritionTargets fromPlanText(String? text) {
    if (text == null || text.trim().isEmpty) return const NutritionTargets();

    final cal = RegExp(
      r'(\d[\d,]{2,5})\s*(?:kcal|calories|cal)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final protein =
        RegExp(
          r'protein[^0-9]{0,20}(\d{2,3})\s*g',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'(\d{2,3})\s*g[^.\n]{0,15}protein',
          caseSensitive: false,
        ).firstMatch(text);

    return NutritionTargets(
      calories: cal == null
          ? null
          : int.tryParse(cal.group(1)!.replaceAll(',', '')),
      protein: protein == null ? null : int.tryParse(protein.group(1)!),
    );
  }
}
