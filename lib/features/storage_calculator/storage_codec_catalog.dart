/// Familia de códec de grabación.
enum RecordingCodecFamily {
  none,
  redcodeDsmc3,
  redcodeRaw,
  arriRaw,
  xOcn,
  cinemaRaw,
  proResRaw,
  bRaw,
  xavc,
}

/// Variante dentro de una familia de códec.
class RecordingCodecVariant {
  final String id;
  final String label;

  const RecordingCodecVariant({required this.id, required this.label});
}

const kRecordingCodecFamilies = <RecordingCodecFamily, String>{
  RecordingCodecFamily.none: 'Ninguno',
  RecordingCodecFamily.redcodeDsmc3: 'REDCODE RAW DSMC3',
  RecordingCodecFamily.redcodeRaw: 'REDCODE RAW',
  RecordingCodecFamily.arriRaw: 'ARRI RAW',
  RecordingCodecFamily.xOcn: 'Sony X-OCN',
  RecordingCodecFamily.cinemaRaw: 'Canon Cinema RAW',
  RecordingCodecFamily.proResRaw: 'Apple ProRes RAW',
  RecordingCodecFamily.bRaw: 'BMD BRAW',
  RecordingCodecFamily.xavc: 'XAVC',
};

const kRecordingCodecVariants = <RecordingCodecFamily, List<RecordingCodecVariant>>{
  RecordingCodecFamily.none: [],
  RecordingCodecFamily.redcodeDsmc3: [
    RecordingCodecVariant(id: 'HQ', label: 'HQ'),
    RecordingCodecVariant(id: 'MQ', label: 'MQ'),
    RecordingCodecVariant(id: 'LQ', label: 'LQ'),
    RecordingCodecVariant(id: 'ELQ', label: 'ELQ'),
  ],
  RecordingCodecFamily.redcodeRaw: [
    RecordingCodecVariant(id: '2:1', label: '2:1'),
    RecordingCodecVariant(id: '3:1', label: '3:1'),
    RecordingCodecVariant(id: '4:1', label: '4:1'),
    RecordingCodecVariant(id: '5:1', label: '5:1'),
    RecordingCodecVariant(id: '6:1', label: '6:1'),
    RecordingCodecVariant(id: '7:1', label: '7:1'),
    RecordingCodecVariant(id: '8:1', label: '8:1'),
    RecordingCodecVariant(id: '9:1', label: '9:1'),
    RecordingCodecVariant(id: '10:1', label: '10:1'),
    RecordingCodecVariant(id: '11:1', label: '11:1'),
    RecordingCodecVariant(id: '12:1', label: '12:1'),
    RecordingCodecVariant(id: '13:1', label: '13:1'),
    RecordingCodecVariant(id: '14:1', label: '14:1'),
    RecordingCodecVariant(id: '15:1', label: '15:1'),
    RecordingCodecVariant(id: '16:1', label: '16:1'),
    RecordingCodecVariant(id: '17:1', label: '17:1'),
    RecordingCodecVariant(id: '18:1', label: '18:1'),
    RecordingCodecVariant(id: '19:1', label: '19:1'),
    RecordingCodecVariant(id: '20:1', label: '20:1'),
    RecordingCodecVariant(id: '21:1', label: '21:1'),
    RecordingCodecVariant(id: '22:1', label: '22:1'),
  ],
  RecordingCodecFamily.arriRaw: [
    RecordingCodecVariant(id: 'ARRIRAW_LogC4', label: 'ARRIRAW LogC4'),
    RecordingCodecVariant(id: 'ARRICORE', label: 'ARRICORE'),
    RecordingCodecVariant(id: 'ARRIRAW', label: 'ARRIRAW'),
  ],
  RecordingCodecFamily.xOcn: [
    RecordingCodecVariant(id: 'XT', label: 'XT'),
    RecordingCodecVariant(id: 'ST', label: 'ST'),
    RecordingCodecVariant(id: 'LT', label: 'LT'),
  ],
  RecordingCodecFamily.cinemaRaw: [
    RecordingCodecVariant(id: 'Light', label: 'Light'),
  ],
  RecordingCodecFamily.proResRaw: [
    RecordingCodecVariant(id: 'HQ 12-bit', label: 'HQ 12-bit'),
    RecordingCodecVariant(id: '12-bit', label: '12-bit'),
  ],
  RecordingCodecFamily.bRaw: [
    RecordingCodecVariant(id: '3:1', label: '3:1'),
    RecordingCodecVariant(id: '5:1', label: '5:1'),
    RecordingCodecVariant(id: '8:1', label: '8:1'),
    RecordingCodecVariant(id: '12:1', label: '12:1'),
  ],
  RecordingCodecFamily.xavc: [
    RecordingCodecVariant(id: '4K Class 480 10-bit', label: '4K Class 480 10-bit'),
    RecordingCodecVariant(id: '4K Class 410 10-bit', label: '4K Class 410 10-bit'),
    RecordingCodecVariant(id: '4K Class 300 10-bit', label: '4K Class 300 10-bit'),
    RecordingCodecVariant(id: '2K Class 160 10-bit', label: '2K Class 160 10-bit'),
  ],
};

/// Códec intermedio (ProRes, DNxHR) referenciado a 1920×1080.
class IntermediateCodecSpec {
  final String label;
  final int bytesPerFrameAt1080p;

  const IntermediateCodecSpec({
    required this.label,
    required this.bytesPerFrameAt1080p,
  });
}

/// Referencia PHFX @ 1920×1080, 24 fps — escala lineal por recuento de píxeles.
const kIntermediateCodecs = <IntermediateCodecSpec>[
  IntermediateCodecSpec(
    label: 'Apple ProRes 4444 XQ 12-bit',
    bytesPerFrameAt1080p: 2076180,
  ),
  IntermediateCodecSpec(
    label: 'Apple ProRes 4444 12-bit',
    bytesPerFrameAt1080p: 1436544,
  ),
  IntermediateCodecSpec(
    label: 'Apple ProRes 422 HQ 10-bit',
    bytesPerFrameAt1080p: 960000,
  ),
  IntermediateCodecSpec(
    label: 'Apple ProRes 422 10-bit',
    bytesPerFrameAt1080p: 642368,
  ),
  IntermediateCodecSpec(
    label: 'Apple ProRes 422 LT 10-bit',
    bytesPerFrameAt1080p: 445655,
  ),
  IntermediateCodecSpec(
    label: 'Apple ProRes 422 Proxy 10-bit',
    bytesPerFrameAt1080p: 196639,
  ),
  IntermediateCodecSpec(
    label: 'Avid DNxHR 444 12-bit',
    bytesPerFrameAt1080p: 2076180,
  ),
  IntermediateCodecSpec(
    label: 'Avid DNxHR HQX 12-bit',
    bytesPerFrameAt1080p: 1698693,
  ),
  IntermediateCodecSpec(
    label: 'Avid DNxHR HQ 8-bit',
    bytesPerFrameAt1080p: 1384120,
  ),
  IntermediateCodecSpec(
    label: 'Avid DNxHR SQ 8-bit',
    bytesPerFrameAt1080p: 888685,
  ),
  IntermediateCodecSpec(
    label: 'Avid DNxHR LB 8-bit',
    bytesPerFrameAt1080p: 282768,
  ),
];

const kDpxBitDepths = [8, 10, 12, 14, 16, 18, 24, 32];
