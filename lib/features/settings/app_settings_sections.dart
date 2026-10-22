import 'package:flutter/material.dart';

import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/settings/settings_cloud_link_section.dart';
import '../../core/settings/settings_cloud_storage_section.dart';
import '../../core/settings/settings_cloud_usage_section.dart';
import '../../core/settings/settings_health_section.dart';
import '../../core/settings/settings_section.dart';
import '../../core/settings/settings_storage_section.dart';
import '../../core/settings/settings_widgets.dart';
import '../../core/settings/settings_workspace_members_section.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/update/settings_update_section.dart';
import '../camera_plan/plan_prefs.dart';
import '../optics_lab/optics_prefs.dart';
import '../shoot_documents/shoot_document_prefs.dart';
import '../storyboard/storyboard_prefs.dart';
import '../visual_bible/bible_prefs.dart';
import 'sections/bible_settings_section.dart';
import 'sections/camera_plan_settings_section.dart';
import 'sections/optics_settings_section.dart';
import 'sections/shoot_documents_settings_section.dart';
import 'sections/storyboard_settings_section.dart';
import 'settings_actions.dart';

/// Identificadores de las secciones, para abrir una en concreto.
abstract final class SettingsSectionIds {
  static const cloud = 'cloud';
  static const status = 'status';
  static const updates = 'updates';
  static const storage = 'storage';
  static const help = 'help';
  static const cameraPlan = 'camera_plan';
  static const bible = 'bible';
  static const optics = 'optics';
  static const shootDocuments = 'shoot_documents';
  static const storyboard = 'storyboard';
}

/// Todas las secciones, en el orden del lateral: primero lo de la app por
/// prioridad y después las pantallas. Una pantalla entra aquí cuando tiene
/// ajustes propios.
List<SettingsSectionSpec> appSettingsSections() => [
  SettingsSectionSpec(
    id: SettingsSectionIds.cloud,
    title: 'Cuenta y nube',
    icon: Icons.cloud_outlined,
    color: const Color(0xFF0A84FF),
    group: SettingsGroup.app,
    keywords: const ['sesión', 'supabase', 'cloudinary', 'equipo', 'espacio'],
    builder: (context, _) => const _CloudSection(),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.status,
    title: 'Sincronización y estado',
    icon: Icons.sync,
    color: const Color(0xFF30D158),
    group: SettingsGroup.app,
    description: 'Conexión, servidor y versiones instaladas en cada equipo.',
    keywords: const ['internet', 'supabase', 'versión', 'ipad'],
    builder: (context, _) => CloudRuntimeConfig.isActive
        ? const SettingsHealthSection()
        : Text(
            'La nube no está activa. Actívala en «Cuenta y nube».',
            style: AppTypography.caption(context.palette),
          ),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.updates,
    title: 'Actualizaciones',
    icon: Icons.system_update_alt,
    color: const Color(0xFF636366),
    group: SettingsGroup.app,
    keywords: const ['versión', 'instalar'],
    builder: (context, _) => SettingsUpdateSection(
      onLoginAction: () => SettingsActions.login(context),
    ),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.storage,
    title: 'Almacenamiento',
    icon: Icons.folder_outlined,
    color: const Color(0xFF8E8E93),
    group: SettingsGroup.app,
    keywords: const ['carpeta', 'ruta', 'datos'],
    builder: (context, _) => const SettingsStorageSection(),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.help,
    title: 'Ayuda',
    icon: Icons.help_outline,
    color: const Color(0xFF5E5CE6),
    group: SettingsGroup.app,
    keywords: const ['tutorial', 'guía', 'errores'],
    builder: (context, _) => const _HelpSection(),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.cameraPlan,
    title: 'Plantas de cámara',
    icon: Icons.grid_on_outlined,
    color: const Color(0xFF30D158),
    group: SettingsGroup.screens,
    description:
        'Cómo se abre la planta y con qué valores empiezan las cámaras y los '
        'esquemas de luz.',
    prefKeys: PlanPrefs.all,
    keywords: const ['imán', 'exposición', 'iso', 'luz', 'ambiente'],
    builder: (context, scope) => CameraPlanSettingsSection(scope: scope),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.bible,
    title: 'Biblia de fotografía',
    icon: Icons.auto_stories_outlined,
    color: const Color(0xFFFF6B6B),
    group: SettingsGroup.screens,
    prefKeys: BiblePrefs.all,
    keywords: const ['pdf', 'exportar'],
    builder: (context, scope) => BibleSettingsSection(scope: scope),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.optics,
    title: 'Óptica',
    icon: Icons.camera_outlined,
    color: const Color(0xFFFF453A),
    group: SettingsGroup.screens,
    description:
        'Cómo se dibujan las líneas de encuadre al abrir el laboratorio.',
    prefKeys: OpticsPrefs.all,
    keywords: const ['encuadre', 'frame line', 'flt'],
    builder: (context, scope) => OpticsSettingsSection(scope: scope),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.shootDocuments,
    title: 'Documentos de rodaje',
    icon: Icons.description_outlined,
    color: const Color(0xFFBF5AF2),
    group: SettingsGroup.screens,
    description: 'Con qué nace un documento nuevo y sus plantillas.',
    prefKeys: ShootDocumentPrefs.all,
    keywords: const ['plantilla', 'portada', 'pdf'],
    builder: (context, scope) => ShootDocumentsSettingsSection(scope: scope),
  ),
  SettingsSectionSpec(
    id: SettingsSectionIds.storyboard,
    title: 'Storyboard',
    icon: Icons.view_comfy_outlined,
    color: const Color(0xFF5AC8FA),
    group: SettingsGroup.screens,
    prefKeys: StoryboardPrefs.all,
    keywords: const ['vista', 'rejilla'],
    builder: (context, scope) => StoryboardSettingsSection(scope: scope),
  ),
];

class _CloudSection extends StatelessWidget {
  const _CloudSection();

  @override
  Widget build(BuildContext context) {
    final active = CloudRuntimeConfig.isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCloudLinkSection(
          onLoginAction: () => SettingsActions.login(context),
          onMigrationAction: () => SettingsActions.migrateToCloud(context),
        ),
        if (active) ...[
          const SizedBox(height: AppSpacing.lg),
          const SettingsWorkspaceMembersSection(),
          const SizedBox(height: AppSpacing.lg),
          const SettingsCloudUsageSection(),
          const SizedBox(height: AppSpacing.lg),
          const SettingsCloudStorageSection(),
        ],
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chevron = Icon(Icons.chevron_right, color: palette.textTertiary);
    return SettingsGroupBox(
      children: [
        SettingsRow(
          title: 'Ver tutorial inicial',
          subtitle: 'Configuración paso a paso desde el principio',
          trailing: chevron,
          onTap: () => SettingsActions.replayTutorial(context),
        ),
        SettingsRow(
          title: 'Instalación y actualización',
          subtitle: 'Cómo instalar y sincronizar tras actualizar la app',
          trailing: chevron,
          onTap: () => SettingsActions.openInstallGuide(context),
        ),
        Builder(
          builder: (rowContext) => SettingsRow(
            title: 'Compartir registro de errores',
            subtitle: 'Para enviarlo si algo ha fallado',
            trailing: chevron,
            onTap: () => SettingsActions.shareErrorLog(rowContext),
          ),
        ),
      ],
    );
  }
}
