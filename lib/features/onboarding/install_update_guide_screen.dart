import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/update/app_release_service.dart';
import '../../core/update/sidestore_guide_sheet.dart';
import '../../core/update/update_actions_row.dart';
import '../../core/widgets/app_button.dart';
import 'cloud_connection_widgets.dart';

/// Guía completa de instalación y actualización multi-dispositivo.
class InstallUpdateGuideScreen extends ConsumerWidget {
  const InstallUpdateGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final cloud = CloudRuntimeConfig.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instalación y actualización'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _Section(
            title: 'Instalar IRIS DP',
            icon: Icons.download_outlined,
            children: [
              const _SubSection(
                title: 'macOS / Windows — actualizar desde la app',
                bullets: [
                  'Con sesión iniciada verás un banner cuando haya versión nueva',
                  'Pulsa «Actualizar ahora» — descarga e instala sin abrir GitHub',
                  'En Mac: arrastra la app del .dmg a Aplicaciones',
                  'Pulsa «Ya actualicé» para sincronizar proyectos',
                ],
              ),
              const _SubSection(
                title: 'macOS — generar instalador manual',
                bullets: [
                  'En Terminal: cd iris_dp && ./scripts/build_release.sh',
                  'Abre build/dmg/IRIS-DP.dmg → arrastra a Aplicaciones',
                  'Para otro Mac: copia el .dmg (AirDrop, USB, Drive…)',
                  'El script usa .env con SUPABASE_URL y SUPABASE_ANON_KEY',
                ],
              ),
              const _SubSection(
                title: 'macOS — modo desarrollo (flutter run)',
                bullets: [
                  'flutter run NO instala en Aplicaciones; sirve para probar',
                  'Usa ./scripts/run_cloud.sh si tienes .env configurado',
                ],
              ),
              const _SubSection(
                title: 'Windows',
                bullets: [
                  'Ejecuta el instalador o descomprime la carpeta Release',
                  'Inicia iris_dp.exe',
                  'Windows Defender puede pedir permiso la primera vez',
                ],
              ),
              const _SubSection(
                title: 'iPad — SideStore (gratis, uso personal)',
                bullets: [
                  'Cada release incluye IRIS-DP.ipa en GitHub (generado por CI)',
                  'Descarga el IPA desde la app (banner o Ajustes → Estado del sistema)',
                  'Abre el archivo con SideStore — re-firma con tu Apple ID',
                  'Refresca SideStore en Wi‑Fi cada ~7 días para evitar caducidad',
                  'Inicia sesión con el mismo email y pulsa sync',
                ],
              ),
              if (cloud && !Platform.isIOS)
                _IpadDownloadSection(ref: ref),
              if (cloud && Platform.isIOS)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: AppButton(
                    label: 'Guía SideStore',
                    icon: Icons.tablet_mac_outlined,
                    onTap: () async {
                      final release = await fetchIpadRelease(
                        client: ref.read(supabaseClientProvider),
                      );
                      if (!context.mounted) return;
                      await SideStoreGuideSheet.show(
                        context,
                        ipaDownloadUrl: release?.downloadUrl,
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'Error al iniciar sesión',
            icon: Icons.warning_amber_outlined,
            children: [
              Text(
                'Si ves «Failed host lookup» o «No se encuentra el servidor», '
                'la URL de Supabase en la app es incorrecta.',
                style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const TutorialNumberedSteps(
                steps: [
                  'Entra en supabase.com → tu proyecto → Settings → API',
                  'Copia «Project URL» (ej. https://abcdefgh.supabase.co)',
                  'Pégala en iris_dp/.env como SUPABASE_URL',
                  'Reinicia la app o regenera el instalador',
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: '¿Un solo instalador para todo?',
            icon: Icons.devices_outlined,
            children: [
              Text(
                'Mac, Windows e iPad necesitan archivos distintos (.dmg, .exe, .ipa). '
                'El script ./scripts/build_release.sh detecta si estás en Mac o Windows '
                'y genera el instalador correcto para ESE sistema.',
                style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'Primera configuración',
            icon: Icons.tune_outlined,
            children: [
              Text(
                'El tutorial inicial te guía en este orden:',
                style: AppTypography.bodyMedium(palette),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...[
                'Crear cuenta o iniciar sesión (modo nube)',
                'Elegir carpeta de datos técnicos y carpeta de documentos',
                'Migrar proyectos locales a la nube (solo si ya tenías datos)',
                'Tour rápido por la pantalla de proyectos',
              ].map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: AppTypography.bodyMedium(palette)),
                      Expanded(
                        child: Text(s, style: AppTypography.bodyMedium(palette)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (cloud) ...[
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: 'Actualizar la app en otros dispositivos',
              icon: Icons.sync_outlined,
              children: [
                Text(
                  'Tus proyectos viven en la nube (Supabase). Actualizar el '
                  'programa en un Mac no borra ni duplica tus datos: solo '
                  'cambias la versión del cliente.',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _NumberedStep(
                  number: 1,
                  title: 'Instala la nueva versión',
                  body:
                      'En cada dispositivo donde uses IRIS DP, instala la '
                      'actualización igual que la primera vez (.dmg, .exe o App Store).',
                ),
                const _NumberedStep(
                  number: 2,
                  title: 'Abre con la misma cuenta',
                  body:
                      'Inicia sesión con el mismo email y contraseña. No hace '
                      'falta volver a crear workspace ni re-migrar proyectos '
                      'en un dispositivo que ya estaba configurado.',
                ),
                const _NumberedStep(
                  number: 3,
                  title: 'Sincroniza',
                  body:
                      'En la pantalla de proyectos, pulsa el icono de nube. '
                      'Espera a que termine (subida y descarga) antes de editar.',
                ),
                const _NumberedStep(
                  number: 4,
                  title: 'Comprueba tus proyectos',
                  body:
                      'Deberías ver los mismos proyectos que en el dispositivo '
                      'donde actualizaste primero. Si falta algo, vuelve a pulsar sync.',
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: palette.accent, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Las carpetas locales (cache) son por dispositivo. '
                          'La fuente de verdad en modo nube es Supabase. Tras '
                          'actualizar, sync trae los cambios más recientes.',
                          style: AppTypography.caption(palette),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _Section(
            title: 'Problemas frecuentes',
            icon: Icons.help_outline,
            children: [
              _FaqTile(
                q: 'Actualicé en el Mac pero el iPad no muestra cambios',
                a: 'Abre IRIS DP en el iPad, inicia sesión y pulsa sync. '
                    'Comprueba conexión a internet.',
              ),
              _FaqTile(
                q: '¿Tengo que reconfigurar las carpetas tras actualizar?',
                a: 'No, en el mismo dispositivo las rutas guardadas se mantienen. '
                    'Solo configuras carpetas la primera vez en cada máquina.',
              ),
              _FaqTile(
                q: '¿Puedo ver el tutorial otra vez?',
                a: 'Sí: Ajustes → Ver tutorial inicial.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Cerrar',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.accent),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTypography.titleLarge(palette)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _SubSection({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.xs),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('– ', style: AppTypography.bodyMedium(palette)),
                  Expanded(child: Text(b, style: AppTypography.bodyMedium(palette))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _NumberedStep({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: palette.accent,
            child: Text(
              '$number',
              style: AppTypography.caption(palette).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium(palette)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;

  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: AppTypography.titleMedium(palette)),
          const SizedBox(height: 4),
          Text(
            a,
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IpadDownloadSection extends StatelessWidget {
  final WidgetRef ref;

  const _IpadDownloadSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FutureBuilder(
      future: fetchIpadRelease(client: ref.read(supabaseClientProvider)),
      builder: (context, snap) {
        final release = snap.data;
        if (release == null) {
          return Text(
            'Inicia sesión para ver el enlace IPA más reciente.',
            style: AppTypography.caption(palette),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: IpadDownloadLinkRow(
            downloadUrl: release.downloadUrl,
            version: release.version,
          ),
        );
      },
    );
  }
}
