// Prueba previa de ES.B: ¿reconstruye un interior lo bastante bien el Object
// Capture del Mac como para ofrecerlo en IRIS junto a RealityScan?
//
// Uso: swift object_capture_test.swift <carpeta de fotos> <salida.usdz> [reduced|medium|full]
//
// La carpeta de fotos es la de una captura real del iPhone, ya descomprimida.
// Abre el USDZ con Vista Rápida (o impórtalo en IRIS) y compáralo con lo que
// da RealityScan de esas mismas fotos. El protocolo está en docs/PLAN_ESCANEO.md.
import Foundation
import RealityKit

guard CommandLine.arguments.count >= 3 else {
  print("Uso: swift object_capture_test.swift <fotos> <salida.usdz> [reduced|medium|full]")
  exit(2)
}
guard PhotogrammetrySession.isSupported else {
  print("Este Mac no admite Object Capture.")
  exit(1)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let detail: PhotogrammetrySession.Request.Detail =
  switch CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "medium" {
  case "reduced": .reduced
  case "full": .full
  default: .medium
  }

var configuration = PhotogrammetrySession.Configuration()
// Un interior no es un objeto sobre una mesa: sin máscara y con más detalle.
configuration.isObjectMaskingEnabled = false
configuration.featureSensitivity = .high
configuration.sampleOrdering = .sequential

let session = try PhotogrammetrySession(input: input, configuration: configuration)
let started = Date()

Task {
  for try await message in session.outputs {
    switch message {
    case .requestProgress(_, let fraction):
      print(String(format: "%3.0f %%", fraction * 100))
    case .requestComplete(_, .modelFile(let url)):
      print("Hecho en \(Int(Date().timeIntervalSince(started))) s: \(url.path)")
    case .requestError(_, let error):
      print("Falló: \(error)")
      exit(1)
    case .processingComplete:
      exit(0)
    case .invalidSample(let id, let reason):
      print("Foto \(id) no válida: \(reason)")
    case .skippedSample(let id):
      print("Foto \(id) descartada")
    case .processingCancelled:
      exit(1)
    default:
      break
    }
  }
}

try session.process(requests: [.modelFile(url: output, detail: detail)])
RunLoop.main.run()
