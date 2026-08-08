/// Barrel público del motor Biblia v2 (no destructivo).
library;

export 'bible_engine_v2_flag.dart';
export 'bible_v2_policy.dart';
export 'model/bible_block.dart';
export 'model/bible_document.dart';
export 'model/bible_page.dart';
export 'model/bible_block_layout.dart';
export 'model/bible_block_style.dart';
export 'model/bible_image_content.dart';
export 'model/project_entity_reference.dart';
export 'theme/bible_theme.dart';
export 'migration/legacy_to_document_migrator.dart';
export 'migration/freeform_v2_blocks_codec.dart';
export 'commands/bible_document_history.dart';
export 'commands/bible_editor_commands.dart';
export 'persistence/bible_document_store.dart';
export 'templates/bible_template_package.dart';
export 'layout/page_layout_recipe.dart';
export 'layout/page_layout_recipe_registry.dart';
export 'model/bible_page_mode.dart';
export 'renderer/bible_page_renderer.dart';
export 'relations/bible_entity_binding_service.dart';
export 'sync/bible_domain_sync_service.dart';
export 'templates/bible_professional_template_service.dart';
export 'templates/bible_v2_professional_templates.dart';
export 'ai/bible_ai_assist.dart';
