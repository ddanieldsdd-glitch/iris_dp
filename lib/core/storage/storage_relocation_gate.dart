import 'package:flutter/material.dart';

import 'app_storage_config.dart';
import 'legacy_storage_discovery.dart';
import 'local_storage_migration_service.dart';
import 'storage_relocation_dialog.dart';

/// Tras configurar almacenamiento, ofrece mover datos legacy detectados.
class StorageRelocationGate extends StatefulWidget {
  final Widget child;

  const StorageRelocationGate({super.key, required this.child});

  @override
  State<StorageRelocationGate> createState() => _StorageRelocationGateState();
}

class _StorageRelocationGateState extends State<StorageRelocationGate> {
  var _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_checked || !mounted) return;
    _checked = true;

    if (!AppStorageConfig.isConfigured) return;

    final proposal = await LegacyStorageDiscovery.findRelocationProposal();
    if (proposal == null || !mounted) return;

    final dismissed = await LocalStorageMigrationService.wasProposalDismissed(
      proposal.source.databasePath,
    );
    if (dismissed || !mounted) return;

    await runStorageRelocationFlow(context, proposal);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
