/// Specs extendidas para autocompletar cámaras comunes.
class CameraSpecSeed {
  final String brand;
  final String model;
  final double sensorW;
  final double sensorH;
  final double dynamicRangeStops;
  final String colorScience;
  final int nativeIso;
  final List<String> logFormats;

  const CameraSpecSeed({
    required this.brand,
    required this.model,
    required this.sensorW,
    required this.sensorH,
    required this.dynamicRangeStops,
    required this.colorScience,
    required this.nativeIso,
    required this.logFormats,
  });
}

const kExtendedCameraSpecs = [
  CameraSpecSeed(
    brand: 'ARRI',
    model: 'Alexa 35',
    sensorW: 27.99,
    sensorH: 19.22,
    dynamicRangeStops: 17,
    colorScience: 'REVEAL Color Science',
    nativeIso: 800,
    logFormats: ['LogC4', 'LogC3'],
  ),
  CameraSpecSeed(
    brand: 'Sony',
    model: 'Venice 2',
    sensorW: 36.2,
    sensorH: 24.1,
    dynamicRangeStops: 16,
    colorScience: 'S-Gamut3.Cine / S-Log3',
    nativeIso: 800,
    logFormats: ['S-Log3'],
  ),
  CameraSpecSeed(
    brand: 'RED',
    model: 'V-Raptor XL 8K',
    sensorW: 40.96,
    sensorH: 21.6,
    dynamicRangeStops: 17,
    colorScience: 'IPP2 / Log3G10',
    nativeIso: 800,
    logFormats: ['Log3G10'],
  ),
  CameraSpecSeed(
    brand: 'Blackmagic',
    model: 'URSA Mini Pro 12K',
    sensorW: 27.03,
    sensorH: 14.26,
    dynamicRangeStops: 14,
    colorScience: 'Blackmagic Generation 5',
    nativeIso: 800,
    logFormats: ['Blackmagic Film Gen5'],
  ),
];
