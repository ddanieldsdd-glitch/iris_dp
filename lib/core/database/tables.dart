import 'package:drift/drift.dart';

class ProjectGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().nullable().references(ProjectGroups, #id)();
  TextColumn get name => text()();
  TextColumn get director => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get clientName => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('preproduction'))();
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
  TextColumn get characterColorsJson => text().nullable()();
  // JSON mapa nombre → hex: {"GALA": "#E63946", "KARIM": "#2A9D8F"}
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// UUID en Supabase cuando sync cloud está activo.
  TextColumn get cloudId => text().nullable()();
  DateTimeColumn get syncUpdatedAt => dateTime().nullable()();

  /// Última modificación del contenido del proyecto (escenas, planos, etc.).
  DateTimeColumn get contentSyncUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cola de operaciones pendientes hacia la nube.
class CloudSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get localEntityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get processed => boolean().withDefault(const Constant(false))();
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
  IntColumn get locationSiteId =>
      integer().nullable().references(LocationSites, #id)();
  // Localización contenedora (ej. "BOSQUE")
  IntColumn get locationId =>
      integer().nullable().references(LocationBasePlans, #id)();
  // Set de rodaje vinculado (galería, planos, color)
  TextColumn get intExt => text().withDefault(const Constant('EXT'))();
  TextColumn get dayNight => text().withDefault(const Constant('DÍA'))();
  TextColumn get locationColor => text().nullable()();
  // Hex del color de la localización, ej. "#FF6B6B"
  TextColumn get charactersJson => text().nullable()();
  // JSON array de personajes: ["GALA", "KARIM"]
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
  TextColumn get framing => text().nullable()(); // PD, PMC, PA, PG...
  TextColumn get lens => text().nullable()(); // 85mm, 50mm...
  TextColumn get angle => text().nullable()(); // normal, picado, contrapicado
  TextColumn get movement => text().nullable()(); // STEADY, DOLLY, MANO...
  TextColumn get fStop => text().nullable()();
  TextColumn get shutterAngle => text().nullable()();
  IntColumn get fps => integer().nullable()();
  TextColumn get action => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get notesHighlight =>
      text().nullable()(); // 'green'|'yellow'|'red'
  TextColumn get description => text().nullable()();
  TextColumn get referenceImagePath => text().nullable()();
  TextColumn get cameraPlanImagePath => text().nullable()();
  TextColumn get charactersJson => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get scriptAnchorIndex => integer().nullable()();
  BoolColumn get autoNumbering => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Documento de rodaje (Plani, jornada, referencia en set).
class ShootDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get defaultVisibilityJson => text().nullable()();
  TextColumn get layoutPreset =>
      text().withDefault(const Constant('freeform'))();
  TextColumn get shootDate => text().nullable()();
  BoolColumn get isPrimaryOnSet =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get includeCoverInPdf =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Bloque composable dentro de un documento de rodaje.
class ShootDocumentBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().references(ShootDocuments, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get blockType => text()();
  IntColumn get sceneId => integer().nullable().references(Scenes, #id)();
  IntColumn get shotId => integer().nullable().references(Shots, #id)();
  TextColumn get scriptExcerpt => text().nullable()();
  TextColumn get customLabel => text().nullable()();
  TextColumn get noteBody => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get charactersJson => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get visibilityJson => text().nullable()();
  TextColumn get contentOverridesJson => text().nullable()();
}

class ShotReferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shotId => integer().references(Shots, #id)();
  TextColumn get imagePath => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // 'manual' | 'artemis_capture' | 'unreal_render'
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
  BoolColumn get lukaCompatible =>
      boolean().withDefault(const Constant(false))();
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
  RealColumn get dynamicRangeStops => real().nullable()();
  TextColumn get colorScience => text().nullable()();
  IntColumn get nativeIso => integer().nullable()();
  TextColumn get logFormats => text().nullable()();
  TextColumn get mountType => text().nullable()();
  TextColumn get sensorModesJson => text().nullable()();
  TextColumn get recordingResolutionsJson => text().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get powerDrawW => real().nullable()();
  TextColumn get heroImagePath => text().nullable()();
  TextColumn get manufacturerUrl => text().nullable()();
  TextColumn get externalId => text().nullable()();
  IntColumn get catalogVersion => integer().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get series => text().nullable()();
  BoolColumn get vintage => boolean().withDefault(const Constant(false))();
  TextColumn get rentalTagsJson => text().nullable()();
  BoolColumn get lukaCompatible =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lukaProfileJson => text().nullable()();
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
  TextColumn get mountType => text().nullable()();
  RealColumn get imageCircleMm => real().nullable()();
  BoolColumn get isAnamorphic => boolean().withDefault(const Constant(false))();
  RealColumn get squeezeRatio => real().nullable()();
  RealColumn get closeFocusM => real().nullable()();
  RealColumn get frontDiameterMm => real().nullable()();
  TextColumn get lensType => text().nullable()();
  TextColumn get heroImagePath => text().nullable()();
  TextColumn get externalId => text().nullable()();
  IntColumn get catalogVersion => integer().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get series => text().nullable()();
  BoolColumn get vintage => boolean().withDefault(const Constant(false))();
  TextColumn get rentalTagsJson => text().nullable()();
  BoolColumn get lukaCompatible =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lukaProfileJson => text().nullable()();
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
  RealColumn get beamAngleDeg => real().nullable()();
  IntColumn get cri => integer().nullable()();
  IntColumn get tlci => integer().nullable()();
  TextColumn get dimmingType => text().nullable()();
  TextColumn get modifierCompatibilityJson => text().nullable()();
  TextColumn get heroImagePath => text().nullable()();
  TextColumn get externalId => text().nullable()();
  IntColumn get catalogVersion => integer().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get series => text().nullable()();
  BoolColumn get vintage => boolean().withDefault(const Constant(false))();
  TextColumn get rentalTagsJson => text().nullable()();
  TextColumn get lukaProfileJson => text().nullable()();
  TextColumn get notes => text().nullable()();
}

class LukaSyncMeta extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteVersion => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
}

class CatalogSyncMeta extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteVersion => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
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
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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

/// Capas vectoriales de anotación reutilizables por cualquier módulo.
///
/// [targetType] + [targetId] identifican el lienzo: por ejemplo
/// `camera_plan_shot/42`, `location_set/8` o `pdf_page/documento:pagina`.
class ProjectAnnotationDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get documentJson => text()();
  IntColumn get documentSchemaVersion =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, targetType, targetId},
  ];
}

/// Biblia visual de producción (manual operativo del look).
class VisualBibles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();

  TextColumn get visualConcept => text().nullable()();
  TextColumn get narrativeReferences => text().nullable()();
  // JSON: [{title, director, dp, year, note}]

  TextColumn get tone => text().nullable()();
  TextColumn get creativeIntention => text().nullable()();
  TextColumn get stagingApproach => text().nullable()();
  TextColumn get pointOfView => text().nullable()();
  TextColumn get directionNarrativeIntent => text().nullable()();
  TextColumn get depthOfFieldNotes => text().nullable()();

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

  IntColumn get primaryCameraId =>
      integer().nullable().references(Cameras, #id)();
  TextColumn get recordingFormat => text().nullable()();
  TextColumn get codec => text().nullable()();
  TextColumn get resolutionNotes => text().nullable()();
  TextColumn get frameRateNotes => text().nullable()();
  IntColumn get nativeIso => integer().nullable()();
  TextColumn get defaultTStop => text().nullable()();
  TextColumn get ndNotes => text().nullable()();
  TextColumn get deliveryColorSpace => text().nullable()();
  TextColumn get captureResolution => text().nullable()();
  TextColumn get deliveryResolution => text().nullable()();
  TextColumn get workflowPipeline => text().nullable()();
  // JSON
  TextColumn get diffusionNotes => text().nullable()();
  TextColumn get sensorShadowBehavior => text().nullable()();
  TextColumn get colorScienceNotes => text().nullable()();
  TextColumn get lowLightNotes => text().nullable()();
  TextColumn get opticCharacterNotes => text().nullable()();
  TextColumn get filtrationNotes => text().nullable()();
  TextColumn get cameraMovementsJson => text().nullable()();
  // JSON: [{movement, narrative, reference}]
  TextColumn get actVisualNotes => text().nullable()();
  // JSON: [{act, intent}]

  TextColumn get cameraNarrativeIntent => text().nullable()();
  TextColumn get opticsNarrativeIntent => text().nullable()();
  TextColumn get exposureNarrativeIntent => text().nullable()();
  TextColumn get lightingNarrativeIntent => text().nullable()();
  TextColumn get colorNarrativeIntent => text().nullable()();
  TextColumn get formatNarrativeIntent => text().nullable()();
  TextColumn get textureNarrativeIntent => text().nullable()();
  TextColumn get conceptNarrativeIntent => text().nullable()();
  TextColumn get opticsConfigJson => text().nullable()();

  /// `false` solo en Biblias nuevas que aún no han elegido cómo comenzar.
  /// Las filas existentes migran como inicializadas para conservar su layout.
  BoolColumn get structureInitialized =>
      boolean().withDefault(const Constant(true))();

  /// `legacy` = motor Group→Section; `v2` = BibleDocument modular.
  TextColumn get engineVersion =>
      text().withDefault(const Constant('legacy'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class BibleSectionEvidence extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get sectionId => text()();
  TextColumn get targetType => text().withDefault(const Constant('section'))();
  IntColumn get targetId => integer().nullable()();
  TextColumn get imagePath => text()();
  TextColumn get caption => text().nullable()();
  TextColumn get equipmentRefJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class ExposureBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get blockName => text()();
  TextColumn get highlightStrategy => text().nullable()();
  TextColumn get shadowStrategy => text().nullable()();
  TextColumn get keyFillRatio => text().nullable()();
  TextColumn get narrativeIntent => text().nullable()();
  TextColumn get referenceImages => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class LightingSetups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get setupName => text()();
  TextColumn get narrativeNote => text().nullable()();
  TextColumn get diagramJson => text()();
  TextColumn get gelNotes => text().nullable()();
  TextColumn get practicalMotivation => text().nullable()();
  TextColumn get referenceImagePath => text().nullable()();
  IntColumn get locationBasePlanId =>
      integer().nullable().references(LocationBasePlans, #id)();
  IntColumn get locationSiteId =>
      integer().nullable().references(LocationSites, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class CameraTests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get testName => text()();
  IntColumn get cameraId => integer().nullable().references(Cameras, #id)();
  IntColumn get lensId => integer().nullable().references(Lenses, #id)();
  TextColumn get lutName => text().nullable()();
  TextColumn get lightCondition => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePaths => text()();
  // JSON array
  DateTimeColumn get testedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class VisualBibleVersions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get label => text()();
  TextColumn get snapshotJson => text()();
  TextColumn get changeNote => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BibleComments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get authorRole => text()();
  // dp | gaffer | colorist | ac
  TextColumn get targetType => text()();
  // moodboard | camera_test | lighting_setup | section
  IntColumn get targetId => integer().nullable()();
  TextColumn get comment => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get locationSiteId =>
      integer().nullable().references(LocationSites, #id)();
  IntColumn get locationBasePlanId =>
      integer().nullable().references(LocationBasePlans, #id)();
  TextColumn get lightingNote => text().nullable()();
  TextColumn get colorNote => text().nullable()();
  TextColumn get stagingNote => text().nullable()();
  TextColumn get referenceImages => text().nullable()();
  TextColumn get linkedShotIds => text().nullable()();
  // JSON array de IDs de plano
  TextColumn get solarOrientation => text().nullable()();
  TextColumn get availableLightHours => text().nullable()();
  TextColumn get existingPracticals => text().nullable()();
  IntColumn get estimatedColorTempKelvin => integer().nullable()();
}

/// Grupos del sidebar de la biblia (Narrativa, Técnica de imagen, etc.).
class BibleSectionGroups extends Table {
  TextColumn get id => text()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get label => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id, bibleId};
}

/// Definición de secciones de la biblia (renombrables / custom).
class BibleSectionDefinitions extends Table {
  TextColumn get id => text()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  TextColumn get groupId => text()();
  TextColumn get label => text()();
  TextColumn get iconKey => text().withDefault(const Constant('article'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(true))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  TextColumn get template => text().withDefault(const Constant('standard'))();
  TextColumn get contentJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id, bibleId};
}

/// Plantillas de usuario (biblia visual, documentos de rodaje).
class UserTemplates extends Table {
  TextColumn get id => text()();

  /// `bible_layout` | `shoot_document`
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get payloadJson => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MoodboardGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get category => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class MoodboardImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get bibleId => integer().nullable().references(VisualBibles, #id)();
  TextColumn get imagePath => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // manual | scouting | artemis_capture | unreal_render | script_reference
  TextColumn get category => text().nullable()();
  // lighting | color | framing | texture | location | character | reference
  IntColumn get groupId =>
      integer().nullable().references(MoodboardGroups, #id)();
  TextColumn get caption => text().nullable()();
  TextColumn get filmReference => text().nullable()();
  IntColumn get linkedSceneId => integer().nullable()();
  TextColumn get linkedLocationName => text().nullable()();
  IntColumn get linkedLocationBasePlanId =>
      integer().nullable().references(LocationBasePlans, #id)();

  /// JSON: secciones de la biblia donde debe aparecer (ej. ["lighting","concept"]).
  TextColumn get assignedSections => text().nullable()();
  /// JSON: ids de narrative cards donde refuerza el detalle (ej. [12, 34]).
  TextColumn get assignedCardIds => text().nullable()();
  /// JSON: MoodboardReferenceMeta (tags, luz, composición, etc.)
  /// Migrado desde SharedPreferences en schemaVersion 39.
  TextColumn get metaJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Cartas narrativas del deck por sección (estilos, refs fílmicas, loc. luz…).
class VisualBibleNarrativeCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  /// BibleSectionId (p. ej. lighting); reutilizable en color/texture.
  TextColumn get sectionId => text()();
  /// style | film_ref | location_light | overview
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  IntColumn get coverMoodboardImageId =>
      integer().nullable().references(MoodboardImages, #id)();
  IntColumn get locationBasePlanId =>
      integer().nullable().references(LocationBasePlans, #id)();
  /// JSON libre (summary, filmTitle, year, dp…).
  TextColumn get metaJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Imágenes de muestra del laboratorio óptico (FLT), por proyecto (máx. 10).
class OpticsLabSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get imagePath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cola local de subidas pendientes a Cloudinary.
class PendingMediaUploads extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get projectCloudId => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityKey => text()();
  TextColumn get localPath => text()();
  TextColumn get publicId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get retries => integer().withDefault(const Constant(0))();
  TextColumn get source => text().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending|processing|done|failed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Documento modular Biblia v2 (Page → Block). No reemplaza VisualBibles.
/// Nombre de tabla distinto a la clase de dominio [BibleDocument].
class VisualBibleDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bibleId => integer().references(VisualBibles, #id)();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get documentJson => text()();
  IntColumn get documentSchemaVersion =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
