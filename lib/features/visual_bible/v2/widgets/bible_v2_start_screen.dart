import 'package:flutter/material.dart';

import '../../widgets/bible_creation_onboarding.dart';

/// Empty state inicial para biblias V2 sin páginas.
class BibleV2StartScreen extends StatelessWidget {
  final VoidCallback onCreateFirstPage;
  final VoidCallback onBrowseTemplates;
  final VoidCallback? onExploreExamples;

  const BibleV2StartScreen({
    super.key,
    required this.onCreateFirstPage,
    required this.onBrowseTemplates,
    this.onExploreExamples,
  });

  @override
  Widget build(BuildContext context) {
    return BibleCreationOnboarding(
      onUseTemplate: onBrowseTemplates,
      onStartFromScratch: onCreateFirstPage,
      onExploreTemplates: onExploreExamples ?? onBrowseTemplates,
      subtitle:
          'Empieza con una plantilla profesional o construye tu Biblia '
          'modular desde cero.',
    );
  }
}

/// Empty state cuando el documento existe pero no tiene páginas.
class BibleV2EmptyDocumentState extends StatelessWidget {
  final VoidCallback onCreateFirstPage;
  final VoidCallback onBrowseTemplates;

  const BibleV2EmptyDocumentState({
    super.key,
    required this.onCreateFirstPage,
    required this.onBrowseTemplates,
  });

  @override
  Widget build(BuildContext context) {
    return BibleCreationOnboarding(
      onUseTemplate: onBrowseTemplates,
      onStartFromScratch: onCreateFirstPage,
      onExploreTemplates: onBrowseTemplates,
      title: 'Tu Biblia está vacía',
      subtitle: 'Elige una plantilla profesional o crea tu primera página.',
    );
  }
}
