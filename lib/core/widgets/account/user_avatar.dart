import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../cloud/user_profile.dart';
import '../../theme/app_colors.dart';

/// Avatar redondo: foto local, foto en la nube o iniciales.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    this.bytes,
    this.size = 28,
    this.ringColor,
  });

  final UserProfile profile;
  final Uint8List? bytes;
  final double size;

  /// Aro exterior (p. ej. verde = sesión iniciada).
  final Color? ringColor;

  static const _tints = [
    Color(0xFF5B8DEF),
    Color(0xFF8E6CEF),
    Color(0xFFE0795A),
    Color(0xFF3FA796),
    Color(0xFFD1A23B),
    Color(0xFFCF5C8A),
  ];

  /// Color estable por persona para el fondo de las iniciales.
  static Color tintFor(String id) =>
      _tints[id.codeUnits.fold<int>(0, (a, b) => a + b) % _tints.length];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initials = Container(
      color: tintFor(profile.id),
      alignment: Alignment.center,
      child: Text(
        profile.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    Widget face;
    if (bytes != null) {
      face = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => initials,
      );
    } else if (profile.hasAvatar) {
      face = Image.network(
        profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => initials,
      );
    } else {
      face = initials;
    }

    final ring = ringColor;
    return Semantics(
      label: 'Avatar de ${profile.label}',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: ring == null ? null : const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring, width: 2),
          color: ring == null ? null : palette.surface,
        ),
        child: ClipOval(child: SizedBox.expand(child: face)),
      ),
    );
  }
}
