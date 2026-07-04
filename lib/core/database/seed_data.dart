/// Datos iniciales del catálogo de equipo (seed en migración v9).
class SeedCamera {
  final String brand;
  final String model;
  final double sensorW;
  final double sensorH;

  const SeedCamera({
    required this.brand,
    required this.model,
    required this.sensorW,
    required this.sensorH,
  });
}

class SeedLens {
  final String brand;
  final String model;
  final double focalLength;
  final double? focalMin;
  final double? focalMax;
  final double minTStop;
  final String formatCoverage;

  const SeedLens({
    required this.brand,
    required this.model,
    required this.focalLength,
    this.focalMin,
    this.focalMax,
    required this.minTStop,
    required this.formatCoverage,
  });
}

class SeedLight {
  final String brand;
  final String model;
  final String type;
  final int powerW;
  final int cMin;
  final int cMax;
  final bool luka;
  final String? lukaFixtureId;

  const SeedLight({
    required this.brand,
    required this.model,
    required this.type,
    required this.powerW,
    required this.cMin,
    required this.cMax,
    this.luka = false,
    this.lukaFixtureId,
  });
}

const kSeedCameras = [
  SeedCamera(brand: 'ARRI', model: 'ALEXA 35', sensorW: 27.99, sensorH: 19.22),
  SeedCamera(
      brand: 'ARRI', model: 'ALEXA Mini LF', sensorW: 36.70, sensorH: 25.54),
  SeedCamera(
      brand: 'RED', model: 'V-RAPTOR 8K VV', sensorW: 40.96, sensorH: 21.60),
  SeedCamera(
      brand: 'Sony', model: 'VENICE 2 8K', sensorW: 35.90, sensorH: 24.00),
  SeedCamera(
      brand: 'Blackmagic', model: 'PYXIS 6K', sensorW: 23.10, sensorH: 12.99),
  SeedCamera(brand: 'Sony', model: 'FX9', sensorW: 35.60, sensorH: 23.80),
];

const kSeedLenses = [
  SeedLens(
    brand: 'Zeiss',
    model: 'Master Prime 35mm',
    focalLength: 35,
    minTStop: 1.4,
    formatCoverage: 'FF',
  ),
  SeedLens(
    brand: 'Zeiss',
    model: 'Master Prime 50mm',
    focalLength: 50,
    minTStop: 1.4,
    formatCoverage: 'FF',
  ),
  SeedLens(
    brand: 'Cooke',
    model: 'S4/i 85mm',
    focalLength: 85,
    minTStop: 2.0,
    formatCoverage: 'S35',
  ),
  SeedLens(
    brand: 'Angenieux',
    model: 'Optimo 24-290',
    focalLength: 0,
    focalMin: 24,
    focalMax: 290,
    minTStop: 2.8,
    formatCoverage: 'S35',
  ),
  SeedLens(
    brand: 'Canon',
    model: 'CN-E 14mm',
    focalLength: 14,
    minTStop: 2.8,
    formatCoverage: 'FF',
  ),
];

const kSeedLights = [
  SeedLight(
    brand: 'ARRI',
    model: 'SkyPanel S360-C',
    type: 'led_panel',
    powerW: 900,
    cMin: 2800,
    cMax: 10000,
    luka: true,
    lukaFixtureId: 'skypanel_s360',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'SkyPanel S120-C',
    type: 'led_panel',
    powerW: 300,
    cMin: 2800,
    cMax: 10000,
    luka: true,
    lukaFixtureId: 'skypanel_s120',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'SkyPanel S60-C',
    type: 'led_panel',
    powerW: 475,
    cMin: 2800,
    cMax: 10000,
    luka: true,
    lukaFixtureId: 'skypanel_s60',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'SkyPanel S30-C',
    type: 'led_panel',
    powerW: 200,
    cMin: 2800,
    cMax: 10000,
    luka: true,
    lukaFixtureId: 'skypanel_s30',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'Orbiter',
    type: 'led',
    powerW: 650,
    cMin: 2000,
    cMax: 6500,
    luka: true,
    lukaFixtureId: 'orbiter',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'L7-C',
    type: 'fresnel',
    powerW: 250,
    cMin: 2800,
    cMax: 10000,
    luka: true,
    lukaFixtureId: 'l7c',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'T24',
    type: 'fresnel',
    powerW: 24000,
    cMin: 3200,
    cMax: 3200,
    luka: true,
    lukaFixtureId: 't24',
  ),
  SeedLight(
    brand: 'ARRI',
    model: 'T12',
    type: 'fresnel',
    powerW: 12000,
    cMin: 3200,
    cMax: 3200,
    luka: true,
    lukaFixtureId: 't12',
  ),
  SeedLight(
    brand: 'Aputure',
    model: 'STORM 1200d',
    type: 'hmi',
    powerW: 1200,
    cMin: 5600,
    cMax: 5600,
  ),
  SeedLight(
    brand: 'Aputure',
    model: 'LS 600d',
    type: 'led',
    powerW: 600,
    cMin: 5600,
    cMax: 5600,
  ),
  SeedLight(
    brand: 'Litepanels',
    model: 'Gemini 2x1',
    type: 'led_panel',
    powerW: 200,
    cMin: 2700,
    cMax: 6500,
  ),
  SeedLight(
    brand: 'Astera',
    model: 'Titan Tube',
    type: 'led_tube',
    powerW: 40,
    cMin: 1800,
    cMax: 20000,
  ),
];
