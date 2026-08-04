import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../luka_export/luka_compatibility_service.dart';

/// Formulario editable para setup manual LUKA (cámara/óptica).
class LukaManualSetupSheet extends StatefulWidget {
  final String equipmentType;
  final Object item;
  final LukaCompatReport report;
  final Future<void> Function(Map<String, dynamic> profile)? onSave;

  const LukaManualSetupSheet({
    super.key,
    required this.equipmentType,
    required this.item,
    required this.report,
    this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String equipmentType,
    required Object item,
    required LukaCompatReport report,
    Future<void> Function(Map<String, dynamic> profile)? onSave,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: LukaManualSetupSheet(
            equipmentType: equipmentType,
            item: item,
            report: report,
            onSave: onSave,
          ),
        ),
      );

  @override
  State<LukaManualSetupSheet> createState() => _LukaManualSetupSheetState();
}

class _LukaManualSetupSheetState extends State<LukaManualSetupSheet> {
  late final TextEditingController _presetCtrl;
  late final TextEditingController _sensorWCtrl;
  late final TextEditingController _sensorHCtrl;
  late final TextEditingController _focalCtrl;
  late final TextEditingController _tStopCtrl;
  late final TextEditingController _squeezeCtrl;
  late final TextEditingController _mountCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final setup = widget.report.manualSetup ?? {};
    _presetCtrl = TextEditingController(text: setup['lukaPreset']?.toString() ?? '');
    _sensorWCtrl = TextEditingController(
      text: _initialSensorW(setup)?.toStringAsFixed(2) ?? '',
    );
    _sensorHCtrl = TextEditingController(
      text: _initialSensorH(setup)?.toStringAsFixed(2) ?? '',
    );
    _focalCtrl = TextEditingController(text: setup['focalMm']?.toString() ?? '');
    _tStopCtrl = TextEditingController(text: setup['tStop']?.toString() ?? '');
    _squeezeCtrl = TextEditingController(text: setup['squeezeRatio']?.toString() ?? '1.0');
    _mountCtrl = TextEditingController(text: setup['mount']?.toString() ?? '');
    _notesCtrl = TextEditingController(text: setup['notes']?.toString() ?? '');
  }

  double? _initialSensorW(Map<String, dynamic> setup) {
    if (setup['sensorWidthMm'] != null) {
      return (setup['sensorWidthMm'] as num).toDouble();
    }
    if (widget.item is Camera) return (widget.item as Camera).sensorWidthMm;
    return null;
  }

  double? _initialSensorH(Map<String, dynamic> setup) {
    if (setup['sensorHeightMm'] != null) {
      return (setup['sensorHeightMm'] as num).toDouble();
    }
    if (widget.item is Camera) return (widget.item as Camera).sensorHeightMm;
    return null;
  }

  Map<String, dynamic> _buildProfile() => {
        if (_presetCtrl.text.isNotEmpty) 'lukaPreset': _presetCtrl.text.trim(),
        if (_sensorWCtrl.text.isNotEmpty) 'sensorWidthMm': double.tryParse(_sensorWCtrl.text),
        if (_sensorHCtrl.text.isNotEmpty) 'sensorHeightMm': double.tryParse(_sensorHCtrl.text),
        if (_focalCtrl.text.isNotEmpty) 'focalMm': double.tryParse(_focalCtrl.text),
        if (_tStopCtrl.text.isNotEmpty) 'tStop': double.tryParse(_tStopCtrl.text),
        if (_squeezeCtrl.text.isNotEmpty) 'squeezeRatio': double.tryParse(_squeezeCtrl.text),
        if (_mountCtrl.text.isNotEmpty) 'mount': _mountCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'manualSetup': true,
      };

  @override
  void dispose() {
    _presetCtrl.dispose();
    _sensorWCtrl.dispose();
    _sensorHCtrl.dispose();
    _focalCtrl.dispose();
    _tStopCtrl.dispose();
    _squeezeCtrl.dispose();
    _mountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_buildProfile());

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ficha manual LUKA', style: AppTypography.titleMedium(palette)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.report.messages.join('\n'),
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.equipmentType == 'camera') ...[
              TextField(
                controller: _presetCtrl,
                decoration: const InputDecoration(labelText: 'Preset LUKA'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sensorWCtrl,
                    decoration: const InputDecoration(labelText: 'Sensor W (mm)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _sensorHCtrl,
                    decoration: const InputDecoration(labelText: 'Sensor H (mm)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (widget.equipmentType == 'lens') ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _focalCtrl,
                      decoration: const InputDecoration(labelText: 'Focal (mm)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _tStopCtrl,
                      decoration: const InputDecoration(labelText: 'T-stop'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _squeezeCtrl,
                      decoration: const InputDecoration(labelText: 'Squeeze'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _mountCtrl,
                      decoration: const InputDecoration(labelText: 'Montura'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas LUKA'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(jsonStr, style: AppTypography.caption(palette)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copiado al portapapeles')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copiar JSON'),
                ),
                const Spacer(),
                if (widget.onSave != null)
                  FilledButton(
                    onPressed: () async {
                      await widget.onSave!(_buildProfile());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Guardar perfil'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de compatibilidad LUKA.
class LukaCompatBadge extends StatelessWidget {
  final LukaCompatReport report;

  const LukaCompatBadge({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (report.level) {
      LukaCompatLevel.full => Colors.green,
      LukaCompatLevel.partial => Colors.amber,
      LukaCompatLevel.manualOnly => Colors.orange,
      LukaCompatLevel.none => palette.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        report.badgeLabel,
        style: AppTypography.caption(palette).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
