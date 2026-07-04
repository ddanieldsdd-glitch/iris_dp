import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de tema de la app. Por defecto: oscuro.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
