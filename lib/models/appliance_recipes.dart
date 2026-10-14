class WashCycleRecipe {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int defaultTempC;
  final String defaultSpinSpeed;
  final bool steamRecommended;
  final bool turboWashSupported;
  final int soilLevel; // 1 to 5
  final bool isDownloaded;

  const WashCycleRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.defaultTempC,
    required this.defaultSpinSpeed,
    this.steamRecommended = false,
    this.turboWashSupported = true,
    this.soilLevel = 3,
    this.isDownloaded = false,
  });

  static const List<WashCycleRecipe> builtInCatalog = [
    WashCycleRecipe(
      id: 'cycle_ai_dd',
      name: 'AI DD Normal',
      description: 'AI fabric sensing automatically adjusts wash motion to optimize fabric protection.',
      durationMinutes: 45,
      defaultTempC: 40,
      defaultSpinSpeed: 'High',
      steamRecommended: false,
    ),
    WashCycleRecipe(
      id: 'cycle_turbowash',
      name: 'TurboWash™ 39',
      description: 'Fast, energy-efficient wash using 3D multi-nozzle spray technology in under 39 minutes.',
      durationMinutes: 39,
      defaultTempC: 40,
      defaultSpinSpeed: 'Max',
      turboWashSupported: true,
    ),
    WashCycleRecipe(
      id: 'cycle_steam_allergy',
      name: 'Steam Allergy Care',
      description: 'High-temperature steam eliminates 99.9% of dust mites, pet dander, and allergens.',
      durationMinutes: 75,
      defaultTempC: 60,
      defaultSpinSpeed: 'Med',
      steamRecommended: true,
      soilLevel: 4,
    ),
    WashCycleRecipe(
      id: 'cycle_bedding',
      name: 'Heavy Bedding & Duvet',
      description: 'Extended soaking and gentle tumbling for bulky blankets, duvets, and pillows.',
      durationMinutes: 80,
      defaultTempC: 40,
      defaultSpinSpeed: 'Med',
      soilLevel: 3,
    ),
    WashCycleRecipe(
      id: 'cycle_delicates',
      name: 'Silk & Delicates',
      description: 'Low-speed swing motion preventing snagging for lace, lingerie, and sheer fabrics.',
      durationMinutes: 35,
      defaultTempC: 30,
      defaultSpinSpeed: 'Low',
      soilLevel: 1,
    ),
  ];

  static const List<WashCycleRecipe> downloadableCatalog = [
    WashCycleRecipe(
      id: 'dl_gym_clothes',
      name: 'Gym & Activewear Odor Care',
      description: 'Specialized enzyme soaking eliminating sweat odors and preserving synthetic elasticity.',
      durationMinutes: 48,
      defaultTempC: 30,
      defaultSpinSpeed: 'Med',
      soilLevel: 4,
      isDownloaded: true,
    ),
    WashCycleRecipe(
      id: 'dl_baby_wear',
      name: 'Baby Wear Sanitization',
      description: 'Steam allergy rinse ensuring zero detergent residue on sensitive newborn garments.',
      durationMinutes: 90,
      defaultTempC: 60,
      defaultSpinSpeed: 'Low',
      steamRecommended: true,
      soilLevel: 5,
      isDownloaded: true,
    ),
    WashCycleRecipe(
      id: 'dl_jeans_denim',
      name: 'Denim & Color Lock',
      description: 'Cold water tumbling preventing color fading and maintaining denim stiffness.',
      durationMinutes: 42,
      defaultTempC: 20,
      defaultSpinSpeed: 'Low',
      soilLevel: 3,
      isDownloaded: true,
    ),
    WashCycleRecipe(
      id: 'dl_tub_clean_coach',
      name: 'Tub Clean Master Care',
      description: 'High-speed 95°C water jet rotation removing limescale and detergent buildup from drum.',
      durationMinutes: 120,
      defaultTempC: 95,
      defaultSpinSpeed: 'Max',
      steamRecommended: true,
      soilLevel: 5,
      isDownloaded: true,
    ),
  ];
}
