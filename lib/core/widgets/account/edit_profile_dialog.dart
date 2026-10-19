import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/profile_providers.dart';
import '../../cloud/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'user_avatar.dart';

/// Elige una imagen y devuelve sus bytes (o null si se cancela).
typedef ImageBytesPicker = Future<Uint8List?> Function();

Future<Uint8List?> pickImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    dialogTitle: 'Foto de perfil',
  );
  return result?.files.single.bytes;
}

/// Nombre visible y foto del perfil propio.
class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({
    super.key,
    required this.snapshot,
    this.pickImage = pickImageBytes,
  });

  final ProfileSnapshot snapshot;
  final ImageBytesPicker pickImage;

  static Future<void> show(
    BuildContext context,
    ProfileSnapshot snapshot, {
    ImageBytesPicker pickImage = pickImageBytes,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          EditProfileDialog(snapshot: snapshot, pickImage: pickImage),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

enum _PhotoChange { none, replace, remove }

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.snapshot.profile.displayName,
  );
  _PhotoChange _photo = _PhotoChange.none;
  Uint8List? _newPhoto;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final bytes = await widget.pickImage();
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = _PhotoChange.replace;
      _newPhoto = bytes;
      _error = null;
    });
  }

  bool get _showsPhoto => switch (_photo) {
    _PhotoChange.replace => true,
    _PhotoChange.remove => false,
    _PhotoChange.none =>
      widget.snapshot.avatarBytes != null || widget.snapshot.profile.hasAvatar,
  };

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(currentProfileProvider.notifier);
    try {
      if (name != widget.snapshot.profile.displayName) {
        await notifier.saveName(name);
      }
      switch (_photo) {
        case _PhotoChange.replace:
          await notifier.setAvatar(_newPhoto!);
        case _PhotoChange.remove:
          await notifier.removeAvatar();
        case _PhotoChange.none:
          break;
      }
      if (mounted) Navigator.of(context).pop();
    } on FormatException {
      setState(
        () => _error = 'Esa imagen no se puede leer. Prueba con JPG o PNG.',
      );
    } catch (e) {
      setState(() => _error = 'No se pudo guardar el perfil. ¿Hay conexión?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = widget.snapshot.profile.copyWith(
      displayName: _name.text,
      clearAvatar: _photo == _PhotoChange.remove,
    );
    final previewBytes = switch (_photo) {
      _PhotoChange.replace => _newPhoto,
      _PhotoChange.remove => null,
      _PhotoChange.none => widget.snapshot.avatarBytes,
    };

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: const Text('Editar perfil'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(profile: profile, bytes: previewBytes, size: 96),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _choosePhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(_showsPhoto ? 'Cambiar foto' : 'Elegir foto'),
                ),
                if (_showsPhoto)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _photo = _PhotoChange.remove;
                            _newPhoto = null;
                          }),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Quitar foto'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre visible'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lo verán las personas con las que compartes proyectos.',
              style: AppTypography.caption(palette),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
