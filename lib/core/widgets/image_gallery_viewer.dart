import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Una imagen del visor: un archivo, unos bytes o unos bytes que se
/// calculan al verla (la planta de un plano, pintada a buena resolución).
class GalleryImage {
  final String label;
  final String? path;
  final Uint8List? bytes;
  final Future<Uint8List?> Function()? load;

  const GalleryImage.file(this.path, {this.label = ''})
    : bytes = null,
      load = null;

  const GalleryImage.memory(this.bytes, {this.label = ''})
    : path = null,
      load = null;

  const GalleryImage.lazy(this.load, {this.label = ''})
    : path = null,
      bytes = null;
}

/// Abre las [images] a pantalla completa, empezando por [initial]: se
/// amplían con el pellizco o la rueda, se pasan con el dedo, las flechas
/// del teclado o la tira de abajo, y se cierran con Esc.
Future<void> showImageGallery(
  BuildContext context, {
  required List<GalleryImage> images,
  int initial = 0,
  String title = '',
}) {
  if (images.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => ImageGalleryPage(
        images: images,
        initial: initial.clamp(0, images.length - 1),
        title: title,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class ImageGalleryPage extends StatefulWidget {
  final List<GalleryImage> images;
  final int initial;
  final String title;

  const ImageGalleryPage({
    super.key,
    required this.images,
    this.initial = 0,
    this.title = '',
  });

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;
  // Lo calculado se guarda: volver a una página no la repinta.
  final _loaded = <int, Future<Uint8List?>>{};
  final _focus = FocusNode();

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.images.length) return;
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _image(int i) {
    final image = widget.images[i];
    Widget missing() => const Center(
      child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.white38),
    );
    Widget zoom(Widget child) => InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(child: child),
    );
    if (image.path case final path?) {
      return File(path).existsSync()
          ? zoom(Image.file(File(path), fit: BoxFit.contain))
          : missing();
    }
    if (image.bytes case final bytes?) {
      return zoom(Image.memory(bytes, fit: BoxFit.contain));
    }
    final future = _loaded[i] ??= image.load!();
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final bytes = snap.data;
        return bytes == null
            ? missing()
            : zoom(Image.memory(bytes, fit: BoxFit.contain));
      },
    );
  }

  Widget _thumb(int i) {
    final image = widget.images[i];
    final selected = i == _index;
    final palette = context.palette;
    Widget content;
    if (image.path case final path?) {
      content = Image.file(File(path), fit: BoxFit.cover, cacheWidth: 200);
    } else if (image.bytes case final bytes?) {
      content = Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 200);
    } else {
      content = ColoredBox(
        color: Colors.white10,
        child: Center(
          child: Text(
            image.label,
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              palette,
            ).copyWith(color: Colors.white70, fontSize: 10),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _go(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: selected ? 96 : 80,
        height: selected ? 54 : 45,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? palette.accent : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = widget.images.length;
    final label = widget.images[_index].label;
    final subtitle = [
      if (count > 1) '${_index + 1} de $count',
      if (label.isNotEmpty) label,
    ].join(' · ');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _image(i),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title.isNotEmpty)
                              Text(
                                widget.title,
                                style: AppTypography.label(palette).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: AppTypography.caption(
                                  palette,
                                ).copyWith(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              if (count > 1) ...[
                for (final (side, delta, icon) in [
                  (Alignment.centerLeft, -1, Icons.chevron_left),
                  (Alignment.centerRight, 1, Icons.chevron_right),
                ])
                  Align(
                    alignment: side,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: Icon(icon, color: Colors.white, size: 28),
                          onPressed:
                              (_index + delta >= 0 && _index + delta < count)
                              ? () => _go(_index + delta)
                              : null,
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SizedBox(
                        height: 58,
                        child: ListView(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          children: [for (var i = 0; i < count; i++) _thumb(i)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
