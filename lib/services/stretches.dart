/// Curated warm-up and cool-down stretches. Each id is an entry of the exercise library, so the app can show
/// the same two-frame demo as for any exercise. These are checklists, not timers.
class StretchItem {
  const StretchItem(this.id, this.name, this.dose);
  final String id;
  final String name;
  final String dose;
}

class StretchPlan {
  const StretchPlan({required this.title, required this.subtitle, required this.items});
  final String title;
  final String subtitle;
  final List<StretchItem> items;
}

enum BodyFocus { push, pull, legs, upper, general }

/// Rough body focus of a session from its title, e.g. "Push Day", "Lower Body", "Back and Biceps".
BodyFocus focusOf(String session) {
  final s = session.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);
  if (has(['leg', 'lower', 'squat', 'quad', 'glute', 'hamstring', 'calf'])) return BodyFocus.legs;
  if (has(['pull', 'back', 'lat', 'bicep'])) return BodyFocus.pull;
  if (has(['push', 'chest', 'shoulder', 'tricep', 'delt'])) return BodyFocus.push;
  if (has(['upper', 'arm'])) return BodyFocus.upper;
  return BodyFocus.general;
}

const _before = '30 s each';
const _beforeSide = '10 each side';
const _hold = 'hold 30–45 s';
const _holdSide = 'hold 30–45 s each side';

const _dynamicUpper = [
  StretchItem('Arm_Circles', 'Arm Circles', '10 forward, 10 back'),
  StretchItem('Shoulder_Circles', 'Shoulder Circles', '10 each way'),
  StretchItem('Dynamic_Chest_Stretch', 'Dynamic Chest Stretch', _before),
  StretchItem('Dynamic_Back_Stretch', 'Dynamic Back Stretch', _before),
  StretchItem('Elbow_Circles', 'Elbow Circles', '10 each way'),
  StretchItem('Wrist_Circles', 'Wrist Circles', '10 each way'),
];

const _dynamicLegs = [
  StretchItem('Standing_Hip_Circles', 'Standing Hip Circles', '10 each way'),
  StretchItem('Knee_Circles', 'Knee Circles', '10 each way'),
  StretchItem('Ankle_Circles', 'Ankle Circles', '10 each way'),
  StretchItem('Front_Leg_Raises', 'Front Leg Raises', _beforeSide),
  StretchItem('Inchworm', 'Inchworm', '6 reps'),
  StretchItem('Worlds_Greatest_Stretch', "World's Greatest Stretch", '5 each side'),
];

const _dynamicGeneral = [
  StretchItem('Worlds_Greatest_Stretch', "World's Greatest Stretch", '5 each side'),
  StretchItem('Arm_Circles', 'Arm Circles', '10 forward, 10 back'),
  StretchItem('Standing_Hip_Circles', 'Standing Hip Circles', '10 each way'),
  StretchItem('Inchworm', 'Inchworm', '6 reps'),
  StretchItem('Cat_Stretch', 'Cat Stretch', '8 slow reps'),
];

const _staticPush = [
  StretchItem('Behind_Head_Chest_Stretch', 'Behind Head Chest Stretch', _hold),
  StretchItem('Chest_And_Front_Of_Shoulder_Stretch', 'Chest and Front of Shoulder', _hold),
  StretchItem('Seated_Front_Deltoid', 'Front Deltoid Stretch', _hold),
  StretchItem('Triceps_Stretch', 'Triceps Stretch', _holdSide),
  StretchItem('Shoulder_Stretch', 'Shoulder Stretch', _holdSide),
];

const _staticPull = [
  StretchItem('Overhead_Lat', 'Overhead Lat Stretch', _hold),
  StretchItem('One_Arm_Against_Wall', 'One Arm Against Wall', _holdSide),
  StretchItem('Standing_Biceps_Stretch', 'Standing Biceps Stretch', _holdSide),
  StretchItem('Upper_Back_Stretch', 'Upper Back Stretch', _hold),
  StretchItem('Kneeling_Forearm_Stretch', 'Kneeling Forearm Stretch', _hold),
  StretchItem('Childs_Pose', "Child's Pose", _hold),
];

const _staticLegs = [
  StretchItem('Quad_Stretch', 'Quad Stretch', _holdSide),
  StretchItem('Kneeling_Hip_Flexor', 'Kneeling Hip Flexor', _holdSide),
  StretchItem('Hamstring_Stretch', 'Hamstring Stretch', _holdSide),
  StretchItem('Standing_Gastrocnemius_Calf_Stretch', 'Standing Calf Stretch', _holdSide),
  StretchItem('Lying_Glute', 'Lying Glute Stretch', _holdSide),
  StretchItem('Adductor_Groin', 'Adductor / Groin Stretch', _hold),
];

/// 4–6 dynamic moves, about five minutes in total.
StretchPlan warmupFor(String session) {
  final items = switch (focusOf(session)) {
    BodyFocus.legs => _dynamicLegs,
    BodyFocus.push || BodyFocus.pull || BodyFocus.upper => _dynamicUpper,
    BodyFocus.general => _dynamicGeneral,
  };
  return StretchPlan(title: 'Warm-up', subtitle: 'About 5 min · dynamic, keep moving', items: items);
}

/// 4–6 static holds of 30–45 seconds for the muscles the session worked.
StretchPlan cooldownFor(String session) {
  final items = switch (focusOf(session)) {
    BodyFocus.legs => _staticLegs,
    BodyFocus.push => _staticPush,
    BodyFocus.pull => _staticPull,
    BodyFocus.upper => [..._staticPush.take(3), ..._staticPull.take(3)],
    BodyFocus.general => [..._staticPush.take(2), ..._staticPull.take(2), ..._staticLegs.take(2)],
  };
  return StretchPlan(title: 'Cool-down', subtitle: 'Hold each 30–45 s · breathe slowly', items: items);
}
