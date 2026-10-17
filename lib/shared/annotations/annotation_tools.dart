import 'package:flutter/material.dart';

import 'annotation_document.dart';

/// Nombre e icono de cada herramienta, compartidos por todas las barras.
abstract final class AnnotationTools {
  static String label(AnnotationToolType tool) => switch (tool) {
    AnnotationToolType.pen => 'Bolígrafo',
    AnnotationToolType.highlighter => 'Subrayador',
    AnnotationToolType.arrow => 'Flecha',
    AnnotationToolType.eraser => 'Borrar trazo',
    AnnotationToolType.select => 'Mover',
    AnnotationToolType.pencil => 'Lápiz',
    AnnotationToolType.ink => 'Tinta',
    AnnotationToolType.marker => 'Rotulador',
    AnnotationToolType.charcoal => 'Carboncillo',
    AnnotationToolType.wash => 'Aguada',
    AnnotationToolType.airbrush => 'Aerógrafo',
    AnnotationToolType.fill => 'Relleno',
    AnnotationToolType.hatch => 'Trama',
    AnnotationToolType.line => 'Recta',
    AnnotationToolType.eraseArea => 'Goma',
    AnnotationToolType.stamp => 'Sellos',
    AnnotationToolType.text => 'Texto',
  };

  static String hint(AnnotationToolType tool) => switch (tool) {
    AnnotationToolType.pencil ||
    AnnotationToolType.ink ||
    AnnotationToolType.pen ||
    AnnotationToolType.marker ||
    AnnotationToolType.charcoal =>
      'Mantén quieto el lápiz al acabar y el trazo se endereza: recta, '
          'paredes, rectángulo o círculo.',
    AnnotationToolType.wash =>
      'Mancha translúcida: repasa para oscurecer y dar profundidad.',
    AnnotationToolType.airbrush =>
      'Niebla suave para luz, brillo, humo o sombra difusa.',
    AnnotationToolType.fill || AnnotationToolType.hatch =>
      'Rodea un área y se pinta entera. Mantén al cerrar para '
          'hacerla rectángulo o elipse.',
    AnnotationToolType.line => 'Arrastra de punta a punta. Se ajusta a 45°.',
    AnnotationToolType.arrow =>
      'Arrastra para marcar dirección. «Recorrido» sigue el trazo, discontinuo.',
    AnnotationToolType.stamp =>
      'Toca para colocar. Arrastra antes de soltar para orientarlo.',
    AnnotationToolType.text => 'Toca donde quieras escribir.',
    AnnotationToolType.select =>
      'Toca un trazo o un sello para moverlo, o rodea varios con el lazo y '
          'arrástralos juntos. En un sello, el punto azul lo gira y el ámbar '
          'abre o alarga el haz; tócalo otra vez para ponerle nombre.',
    AnnotationToolType.eraseArea => 'Borra como una goma de verdad.',
    AnnotationToolType.eraser => 'Toca un trazo o sello para quitarlo entero.',
    AnnotationToolType.highlighter => 'Marca translúcida para resaltar.',
  };

  static IconData icon(AnnotationToolType tool) => switch (tool) {
    AnnotationToolType.pen => Icons.edit,
    AnnotationToolType.highlighter => Icons.brush,
    AnnotationToolType.arrow => Icons.north_east,
    AnnotationToolType.eraser => Icons.auto_fix_off,
    AnnotationToolType.select => Icons.open_with,
    AnnotationToolType.pencil => Icons.edit_outlined,
    AnnotationToolType.ink => Icons.draw_outlined,
    AnnotationToolType.marker => Icons.border_color_outlined,
    AnnotationToolType.charcoal => Icons.gesture,
    AnnotationToolType.wash => Icons.water_drop_outlined,
    AnnotationToolType.airbrush => Icons.blur_on,
    AnnotationToolType.fill => Icons.format_color_fill,
    AnnotationToolType.hatch => Icons.texture,
    AnnotationToolType.line => Icons.horizontal_rule,
    AnnotationToolType.eraseArea => Icons.cleaning_services_outlined,
    AnnotationToolType.stamp => Icons.videocam_outlined,
    AnnotationToolType.text => Icons.title,
  };

  static String stampLabel(AnnotationStampKind kind) => switch (kind) {
    AnnotationStampKind.camera => 'Cámara',
    AnnotationStampKind.actor => 'Personaje',
    AnnotationStampKind.light => 'Foco',
    AnnotationStampKind.softbox => 'Softbox',
    AnnotationStampKind.sun => 'Sol',
    AnnotationStampKind.frame => 'Marco / bandera',
    AnnotationStampKind.text => 'Texto',
    AnnotationStampKind.dolly => 'Dolly',
    AnnotationStampKind.crane => 'Grúa',
    AnnotationStampKind.fresnel => 'Fresnel',
    AnnotationStampKind.hmi => 'HMI',
    AnnotationStampKind.ledPanel => 'Panel LED',
    AnnotationStampKind.tube => 'Tubo',
    AnnotationStampKind.bounce => 'Rebotador',
    AnnotationStampKind.diffusion => 'Difusor',
    AnnotationStampKind.window => 'Ventana',
    AnnotationStampKind.door => 'Puerta',
    AnnotationStampKind.table => 'Mesa',
    AnnotationStampKind.chair => 'Silla',
    AnnotationStampKind.sofa => 'Sofá',
    AnnotationStampKind.car => 'Coche',
  };

  /// Sellos agrupados para elegirlos.
  static const stampGroups = <(String, List<AnnotationStampKind>)>[
    (
      'Cámara',
      [
        AnnotationStampKind.camera,
        AnnotationStampKind.dolly,
        AnnotationStampKind.crane,
      ],
    ),
    ('Personas', [AnnotationStampKind.actor]),
    (
      'Luz',
      [
        AnnotationStampKind.light,
        AnnotationStampKind.fresnel,
        AnnotationStampKind.hmi,
        AnnotationStampKind.ledPanel,
        AnnotationStampKind.tube,
        AnnotationStampKind.softbox,
        AnnotationStampKind.sun,
      ],
    ),
    (
      'Control',
      [
        AnnotationStampKind.frame,
        AnnotationStampKind.bounce,
        AnnotationStampKind.diffusion,
      ],
    ),
    (
      'Decorado',
      [
        AnnotationStampKind.window,
        AnnotationStampKind.door,
        AnnotationStampKind.table,
        AnnotationStampKind.chair,
        AnnotationStampKind.sofa,
        AnnotationStampKind.car,
      ],
    ),
  ];

  /// Herramientas de las barras pequeñas (anotar encima de un plano).
  static const quick = [
    AnnotationToolType.pencil,
    AnnotationToolType.ink,
    AnnotationToolType.marker,
    AnnotationToolType.line,
    AnnotationToolType.arrow,
    AnnotationToolType.eraser,
  ];
}
