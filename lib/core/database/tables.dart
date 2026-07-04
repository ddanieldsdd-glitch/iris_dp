import 'package:drift/drift.dart';

class ProjectGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().nullable().references(ProjectGroups, #id)();
  TextColumn get name => text()();
  TextColumn get director => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get clientName => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('preproduction'))();
  // 'preproduction' | 'shooting' | 'post'
  IntColumn get iconCode => integer().withDefault(const Constant(0xe3f4))();
  // Codepoint del icono (Icons.movie_creation = 0xe3f4)
  TextColumn get coverImagePath => text().nullable()();
  TextColumn get shootingStartDate => text().nullable()();
  TextColumn get shootingEndDate => text().nullable()();
  TextColumn get googleEmail => text().nullable()();
  TextColumn get scriptFilePath => text().nullable()();
  // Ruta local del guion literario (copia en almacenamiento de la app)
  TextColumn get scriptFileName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Scenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get number => integer()();
  TextColumn get name => text()();
  // Nombre visible editable: ej. "La huida de Gala"
  TextColumn get locationCanonical => text()();
  // Localización canónica generada: "EXT. CALLE PUEBLO - NOCHE"
  // Formato: "{INT|EXT}. {NOMBRE} - {DÍA|NOCHE|AMANECER|ATARDECER}"
  TextColumn get locationPureName => text()();
  // Nombre del set de rodaje dentro de la localización (ej. "RÍO")
  IntColumn get locationSiteId => integer().nullable().references(LocationSites, #id)();
  // Localización contenedora (ej. "BOSQUE")
  IntColumn get locationId => integer().nullable().references(LocationBasePlans, #id)();
  // Set de rodaje vinculado (galería, planos, color)
  TextColumn get intExt => text().withDefault(const Constant('EXT'))();
  TextColumn get dayNight => text().withDefault(const Constant('DÍA'))();
  TextColumn get locationColor => text().nullable()();
  // Hex del color de la localización, ej. "#FF6B6B"
  TextColumn get description => text().nullable()();
  TextColumn get actionText => text().nullable()();
  IntColumn get sourceStartIndex => integer().nullable()();
  // Índice en el texto extraído del guion (slugline clickeable)
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get autoNumbering => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Shots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sceneId => integer().references(Scenes, #id)();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get number => integer()();
  TextColumn get framing => text().nullable()();       // PD, PMC, PA, PG...
  TextColumn get lens => text().nullable()();          // 85mm, 50mm...
  TextColumn get angle => text().nullable()();         // normal, picado, contrapicado
  TextColumn get movement => text().nullable()();      // STEADY, DOLLY, MANO...
  TextColumn get fStop => text().nullable()();
  TextColumn get shutterAngle => text().nullable()();
  IntColumn get fps => integer().nullable()();
  TextColumn get action => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get notesHighlight => text().nullable()(); // 'green'|'yellow'|'red'
  TextColumn get description => text().nullable()();
  TextColumn get referenceImagePath => text().nullable()();
  TextColumn get cameraPlanImagePath => text().nullable()();
  BoolColumn get autoNumbering => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class ShotReferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shotId => integer().references(Shots, #id)();
  TextColumn get imagePath => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // 'manual' | 'ai_generated' | 'artemis_capture'
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class CameraPlanElements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shotId => integer().references(Shots, #id)();
  TextColumn get type => text()();
  // 'camera' | 'actor' | 'light' | 'prop' | 'wall'
  RealColumn get x => real().withDefault(const Constant(0.0))();
  RealColumn get y => real().withDefault(const Constant(0.0))();
  RealColumn get rotation => real().withDefault(const Constant(0.0))();
  TextColumn get label => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get cameraStabilization => text().nullable()();
  TextColumn get cameraLens => text().nullable()();
  TextColumn get cameraLetter => text().withDefault(const Constant('A'))();
  IntColumn get cameraNumber => integer().withDefault(const Constant(1))();
  TextColumn get lightType => text().nullable()();
  BoolColumn get lukaCompatible => boolean().withDefault(const Constant(false))();
  TextColumn get lukaFixtureId => text().nullable()();
  TextColumn get externalMappingJson => text().nullable()();
  // Vínculos LUKA / Unreal / Cine Tracer (catálogo, mesh, tipo CT)
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class CameraPathPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get elementId => integer().references(CameraPlanElements, #id)();
  IntColumn get pointNumber => integer()();
  RealColumn get x => real()();
  RealColumn get y => real()();
}

/// Localización de rodaje (contenedor): ej. BOSQUE, HOSPITAL.
class LocationSites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get floorPlanJson => text().nullable()();
  TextColumn get scanPath => text().nullable()();
  // Gaussian splat / mesh (.ply, .luma, .glb…)
  TextColumn get scanSource => text().nullable()();
  // luma_ai | polycam | cinetracer | manual
  TextColumn get scanMetadataJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Imágenes de la localización contenedora (nivel sitio, no set).
class SiteImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer().references(LocationSites, #id)();
  TextColumn get imagePath => text()();
  TextColumn get caption => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('reference'))();
  // 'reference' | 'scouting' | 'mood' | 'access' | 'overview'
  TextColumn get timeOfDay => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Set de rodaje: unidad de scout con galería, color y escenas vinculadas.
class LocationBasePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get siteId => integer().nullable().references(LocationSites, #id)();
  TextColumn get locationName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  // Portada / plano principal (legacy; preferir LocationImages)
  TextColumn get color => text().withDefault(const Constant('#94A3B8'))();
  TextColumn get notes => text().nullable()();
  TextColumn get model3dPath => text().nullable()();
  TextColumn get floorPlanJson => text().nullable()();
  TextColumn get scanPath => text().nullable()();
  TextColumn get scanSource => text().nullable()();
  TextColumn get scanMetadataJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class LocationImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get locationId => integer().references(LocationBasePlans, #id)();
  TextColumn get imagePath => text()();
  TextColumn get caption => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('reference'))();
  // 'reference' | 'scouting' | 'mood' | 'sun_study'
  TextColumn get timeOfDay => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Catálogo global de cámaras.
class Cameras extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();
  TextColumn get model => text()();
  RealColumn get sensorWidthMm => real()();
  RealColumn get sensorHeightMm => real()();
  TextColumn get recordingFormats => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Catálogo global de ópticas.
class Lenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();
  TextColumn get model => text()();
  RealColumn get focalLength => real()();
  RealColumn get focalMin => real().nullable()();
  RealColumn get focalMax => real().nullable()();
  RealColumn get minTStop => real()();
  TextColumn get formatCoverage => text()();
  TextColumn get notes => text().nullable()();
}

/// Catálogo global de luces.
class Lights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();
  TextColumn get model => text()();
  TextColumn get lightType => text()();
  IntColumn get powerW => integer()();
  IntColumn get colorTempMin => integer()();
  IntColumn get colorTempMax => integer()();
  BoolColumn get isLukaCompatible =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lukaFixtureId => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Equipo asignado a un proyecto.
class ProjectEquipment extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get equipmentType => text()();
  IntColumn get equipmentId => integer()();
  TextColumn get source => text().withDefault(const Constant('rental'))();
  TextColumn get status => text().withDefault(const Constant('available'))();
  TextColumn get notes => text().nullable()();
}

/// Look Bible: identidad visual del proyecto (moodboard, LUT, luz…).
class LookBibles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();

  TextColumn get visualConcept => text().nullable()();
  TextColumn get colorPalette => text().nullable()();
  // JSON array de hex colors
  TextColumn get lutName => text().nullable()();
  TextColumn get filmReferences => text().nullable()();
  // JSON array de strings

  TextColumn get lightingPhilosophy => text().nullable()();
  TextColumn get contrastStyle => text().nullable()();

  TextColumn get actOneNotes => text().nullable()();
  TextColumn get actTwoNotes => text().nullable()();
  TextColumn get actThreeNotes => text().nullable()();

  TextColumn get moodboardImages => text().nullable()();
  // JSON array de paths locales

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// PDFs reimportados desde GoodNotes u otras apps de anotación.
class ProjectAnnotatedPdfs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get moduleType => text()();
  // guion_tecnico | planta_camara | orden_rodaje | look_bible | visual_bible | storyboard
  TextColumn get pdfPath => text()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Biblia visual de producción (manual operativo del look).
class VisualBibles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();

  TextColumn get visualConcept => text().nullable()();
  TextColumn get narrativeReferences => text().nullable()();
  // JSON: [{title, director, dp, year, note}]

  TextColumn get lightingPhilosophy => text().nullable()();
  TextColumn get lightQuality => text().nullable()();
  TextColumn get contrastStyle => text().nullable()();
  TextColumn get keyFillRatioDay => text().nullable()();
  TextColumn get keyFillRatioNight => text().nullable()();
  TextColumn get lightSource => text().nullable()();

  TextColumn get cameraPhilosophy => text().nullable()();
  TextColumn get movementStyle => text().nullable()();
  TextColumn get preferredMovements => text().nullable()();
  // JSON array de strings

  TextColumn get lensPhilosophy => text().nullable()();
  TextColumn get opticType => text().nullable()();
  TextColumn get primaryFocalLengths => text().nullable()();
  // JSON array de números
  IntColumn get primaryLensId => integer().nullable().references(Lenses, #id)();

  TextColumn get aspectRatio => text().nullable()();
  TextColumn get aspectRatioJustification => text().nullable()();

  TextColumn get imageTexture => text().nullable()();
  TextColumn get grainLevel => text().nullable()();
  TextColumn get highlightBehavior => text().nullable()();
  TextColumn get shadowBehavior => text().nullable()();

  TextColumn get workingLutName => text().nullable()();
  TextColumn get creativeLutName => text().nullable()();
  TextColumn get creativeLutDescription => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class VisualBibleColorBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get blockName => text()();
  TextColumn get emotionalIntent => text().nullable()();
  TextColumn get dominantColors => text()();
  // JSON array hex
  TextColumn get accentColors => text().nullable()();
  TextColumn get prohibitedColors => text().nullable()();
  IntColumn get colorTempKelvin => integer().nullable()();
  TextColumn get referenceImages => text().nullable()();
  // JSON array paths
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class VisualBibleLocationRefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get locationName => text()();
  TextColumn get lightingNote => text().nullable()();
  TextColumn get colorNote => text().nullable()();
  TextColumn get referenceImages => text().nullable()();
  TextColumn get linkedShotIds => text().nullable()();
  // JSON array de IDs de plano
}

class MoodboardImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get bibleId => integer().nullable().references(VisualBibles, #id)();
  TextColumn get imagePath => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // manual | ai_generated | scouting | artemis_capture | unreal_render | script_reference
  TextColumn get category => text().nullable()();
  // lighting | color | framing | texture | location | character | reference
  TextColumn get caption => text().nullable()();
  TextColumn get filmReference => text().nullable()();
  IntColumn get linkedSceneId => integer().nullable()();
  TextColumn get linkedLocationName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
