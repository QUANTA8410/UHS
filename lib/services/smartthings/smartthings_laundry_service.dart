enum GarmentType {
  shirtsDaily,
  jeansDenim,
  towels,
  delicates,
  bedding,
  babyWear,
  gymActivewear,
}

class LaundryRecipeResult {
  final String recommendedCycle;
  final int recommendedTempC;
  final String recommendedSpin;
  final int rinseCount;
  final bool enableEcoBubble;
  final bool enableBubbleSoak;
  final String advice;

  const LaundryRecipeResult({
    required this.recommendedCycle,
    required this.recommendedTempC,
    required this.recommendedSpin,
    required this.rinseCount,
    required this.enableEcoBubble,
    required this.enableBubbleSoak,
    required this.advice,
  });
}

class SmartThingsLaundryService {
  /// SmartThings AI Laundry Recipe Engine
  LaundryRecipeResult recommendRecipe(Set<GarmentType> selectedGarments) {
    if (selectedGarments.contains(GarmentType.delicates)) {
      return const LaundryRecipeResult(
        recommendedCycle: 'Delicates & Wool',
        recommendedTempC: 30,
        recommendedSpin: 'Low',
        rinseCount: 2,
        enableEcoBubble: true,
        enableBubbleSoak: false,
        advice: 'Gentle cradle motion with low spin protects fine fabrics and prevents snagging.',
      );
    }

    if (selectedGarments.contains(GarmentType.babyWear)) {
      return const LaundryRecipeResult(
        recommendedCycle: 'Hygiene Steam / Baby Care',
        recommendedTempC: 60,
        recommendedSpin: 'Med',
        rinseCount: 4,
        enableEcoBubble: true,
        enableBubbleSoak: true,
        advice: 'High-temperature steam and extra rinses remove 99.9% of bacteria and detergent residue.',
      );
    }

    if (selectedGarments.contains(GarmentType.jeansDenim)) {
      return const LaundryRecipeResult(
        recommendedCycle: 'Denim & Colors',
        recommendedTempC: 30,
        recommendedSpin: 'Med',
        rinseCount: 3,
        enableEcoBubble: true,
        enableBubbleSoak: true,
        advice: 'Cold-water EcoBubble™ penetrates dense denim weave while locking indigo dye.',
      );
    }

    if (selectedGarments.contains(GarmentType.gymActivewear)) {
      return const LaundryRecipeResult(
        recommendedCycle: 'Activewear SuperSpeed',
        recommendedTempC: 30,
        recommendedSpin: 'Med',
        rinseCount: 2,
        enableEcoBubble: true,
        enableBubbleSoak: false,
        advice: 'Speed Spray washes sweat from synthetic dry-fit fibers in 39 minutes.',
      );
    }

    if (selectedGarments.contains(GarmentType.towels) || selectedGarments.contains(GarmentType.bedding)) {
      return const LaundryRecipeResult(
        recommendedCycle: 'Towels & Bedding',
        recommendedTempC: 60,
        recommendedSpin: 'Max',
        rinseCount: 3,
        enableEcoBubble: true,
        enableBubbleSoak: true,
        advice: 'Deep soak with hot water ensures maximum fluffiness and sanitization.',
      );
    }

    // Default AI Wash
    return const LaundryRecipeResult(
      recommendedCycle: 'AI Wash (Auto Sense)',
      recommendedTempC: 40,
      recommendedSpin: 'High',
      rinseCount: 2,
      enableEcoBubble: true,
      enableBubbleSoak: false,
      advice: 'Smart sensors auto-detect load weight and soil turbidity to optimize detergent and time.',
    );
  }

  /// Evaluates SmartThings Home Care maintenance for Samsung Washers
  Map<String, dynamic> checkHomeCareStatus({
    required int drumCleanCount,
    required int detergentPercent,
    required int softenerPercent,
  }) {
    final bool drumCleanNeeded = drumCleanCount >= 40;
    final bool detergentLow = detergentPercent <= 20;
    final bool softenerLow = softenerPercent <= 20;

    return {
      'drumCleanNeeded': drumCleanNeeded,
      'drumCleanCyclesRemaining': (40 - drumCleanCount).clamp(0, 40),
      'detergentLow': detergentLow,
      'softenerLow': softenerLow,
      'meshFilterStatus': 'Normal',
      'careSummary': drumCleanNeeded
          ? 'Run Drum Clean+ cycle now (70°C water)'
          : (detergentLow ? 'Refill Auto Dispenser detergent tank' : 'All systems optimal'),
    };
  }
}
