import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/scene_character_chips.dart';
import 'shoot_document_block_resolver.dart';
import 'shoot_document_block_types.dart';

/// Tarjeta de un bloque en editor o vista previa.
class ShootDocumentBlockTile extends StatelessWidget {
  final ResolvedShootBlock resolved;
  final AppPalette palette;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  const ShootDocumentBlockTile({
    super.key,
    required this.resolved,
    required this.palette,
    this.editing = true,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final block = resolved.block;
    final vis = resolved.visibility;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: palette.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (editing)
                  Icon(Icons.drag_handle, color: palette.textTertiary, size: 20),
                if (editing) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    resolved.title,
                    style: AppTypography.label(palette).copyWith(
                      color: palette.accent,
                    ),
                  ),
                ),
                if (editing)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'dup') onDuplicate?.call();
                      if (v == 'del') onDelete?.call();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                      PopupMenuItem(value: 'del', child: Text('Eliminar')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _bodyForType(block.blockType, vis),
          ],
        ),
      ),
    );
  }

  Widget _bodyForType(String blockType, ShootBlockVisibility vis) {
    return switch (blockType) {
      ShootBlockType.sectionHeader || ShootBlockType.sceneHeader => _headerBody(),
      ShootBlockType.characterList => _charactersBody(vis),
      ShootBlockType.scriptExcerpt => _scriptBody(),
      ShootBlockType.shot => _shotBody(vis),
      ShootBlockType.note => _noteBody(),
      ShootBlockType.image => _imageBody(),
      ShootBlockType.pageBreak => _pageBreakBody(),
      ShootBlockType.spacer => const SizedBox(height: AppSpacing.lg),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _headerBody() {
    return Text(
      resolved.block.customLabel ?? resolved.scene?.locationCanonical ?? '',
      style: AppTypography.titleMedium(palette),
    );
  }

  Widget _charactersBody(ShootBlockVisibility vis) {
    if (!vis.showCharacters) return const SizedBox.shrink();
    final chars = resolved.characters;
    if (chars.isEmpty) {
      return Text('Sin personajes', style: AppTypography.caption(palette));
    }
    return SceneCharacterChips(characters: chars, palette: palette);
  }

  Widget _scriptBody() {
    final text = resolved.block.scriptExcerpt ??
        resolved.scene?.actionText ??
        '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: AppTypography.bodyMedium(palette));
  }

  Widget _shotBody(ShootBlockVisibility vis) {
    final path = resolved.imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vis.showThumbnail && path != null && File(path).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (vis.showThumbnail && path != null) const SizedBox(height: AppSpacing.sm),
        if (vis.showCamera)
          Text(
            [
              if (resolved.framing != null) resolved.framing,
              if (resolved.lens != null) resolved.lens,
              if (resolved.movement != null) resolved.movement,
            ].whereType<String>().join(' · '),
            style: AppTypography.mono(palette),
          ),
        if (vis.showDuration) ...[
          const SizedBox(height: 4),
          Text(
            'Duración: ${formatDurationSeconds(resolved.durationSeconds)}',
            style: AppTypography.caption(palette),
          ),
        ],
        if (vis.showCharacters && resolved.characters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SceneCharacterChips(characters: resolved.characters, palette: palette),
        ],
        if (vis.showAction &&
            resolved.action != null &&
            resolved.action!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(resolved.action!, style: AppTypography.bodyMedium(palette)),
        ],
      ],
    );
  }

  Widget _noteBody() {
    return Text(
      resolved.block.noteBody ?? '',
      style: AppTypography.bodyMedium(palette),
    );
  }

  Widget _imageBody() {
    final path = resolved.block.imagePath;
    if (path == null || !File(path).existsSync()) {
      return Text('Sin imagen', style: AppTypography.caption(palette));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(path), fit: BoxFit.cover),
    );
  }

  Widget _pageBreakBody() {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('— Salto de página —', style: AppTypography.caption(palette)),
        ),
        Expanded(child: Divider(color: palette.divider)),
      ],
    );
  }
}
