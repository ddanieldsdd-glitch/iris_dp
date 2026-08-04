import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/sync/project_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';

/// Invitar director por email a un proyecto (solo DP owner).
class InviteDirectorSheet extends ConsumerStatefulWidget {
  final String projectCloudId;
  final String projectName;

  const InviteDirectorSheet({
    super.key,
    required this.projectCloudId,
    required this.projectName,
  });

  static Future<void> show(
    BuildContext context, {
    required String projectCloudId,
    required String projectName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: InviteDirectorSheet(
          projectCloudId: projectCloudId,
          projectName: projectName,
        ),
      ),
    );
  }

  @override
  ConsumerState<InviteDirectorSheet> createState() =>
      _InviteDirectorSheetState();
}

class _InviteDirectorSheetState extends ConsumerState<InviteDirectorSheet> {
  final _emailCtrl = TextEditingController();
  var _readOnly = false;
  var _saving = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;

    setState(() => _saving = true);
    try {
      final service = ProjectInviteService(client);
      await service.inviteDirector(
        projectCloudId: widget.projectCloudId,
        email: _emailCtrl.text.trim(),
        role: _readOnly ? 'viewer' : 'director',
      );
      if (mounted) {
        AppSnackBar.show(context, 'Invitación enviada');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invitar director',
            style: AppTypography.titleMedium(palette),
          ),
          Text(
            widget.projectName,
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email del director',
              hintText: 'director@estudio.com',
            ),
          ),
          SwitchListTile(
            title: const Text('Solo lectura'),
            value: _readOnly,
            onChanged: (v) => setState(() => _readOnly = v),
          ),
          FilledButton(
            onPressed: _saving ? null : _invite,
            child: Text(_saving ? 'Enviando…' : 'Enviar invitación'),
          ),
        ],
      ),
    );
  }
}
