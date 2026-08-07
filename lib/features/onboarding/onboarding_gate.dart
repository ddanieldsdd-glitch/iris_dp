import 'package:flutter/material.dart';

import 'initial_tutorial_flow.dart';

/// Punto de entrada post-instalación: delega en el tutorial paso a paso.
class OnboardingGate extends StatelessWidget {
  final WidgetBuilder homeContentBuilder;

  const OnboardingGate({
    super.key,
    required this.homeContentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InitialTutorialFlow(homeContentBuilder: homeContentBuilder);
  }
}
