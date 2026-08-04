import 'package:flutter/material.dart';

import 'initial_tutorial_flow.dart';

/// Punto de entrada post-instalación: delega en el tutorial paso a paso.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const InitialTutorialFlow();
  }
}
