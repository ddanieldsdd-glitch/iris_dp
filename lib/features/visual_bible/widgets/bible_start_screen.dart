import 'package:flutter/material.dart';

import 'bible_creation_onboarding.dart';

/// Primera decisión de una Biblia nueva (legacy Stitch).
class BibleStartScreen extends StatelessWidget {
  final VoidCallback onStartEmpty;
  final VoidCallback onBrowseTemplates;
  final VoidCallback onExploreExamples;

  const BibleStartScreen({
    super.key,
    required this.onStartEmpty,
    required this.onBrowseTemplates,
    required this.onExploreExamples,
  });

  @override
  Widget build(BuildContext context) {
    return BibleCreationOnboarding(
      onUseTemplate: onBrowseTemplates,
      onStartFromScratch: onStartEmpty,
      onExploreTemplates: onExploreExamples,
    );
  }
}

/// Estado posterior a elegir «Desde cero».
class EmptyBibleState extends StatelessWidget {
  final VoidCallback onAddScreen;
  final VoidCallback onBrowseTemplates;

  const EmptyBibleState({
    super.key,
    required this.onAddScreen,
    required this.onBrowseTemplates,
  });

  @override
  Widget build(BuildContext context) {
    return BibleCreationOnboarding(
      onUseTemplate: onBrowseTemplates,
      onStartFromScratch: onAddScreen,
      onExploreTemplates: onBrowseTemplates,
      title: 'Biblia de Fotografía',
      subtitle: 'Tu Biblia está vacía. Añade pantallas o aplica una plantilla.',
    );
  }
}
