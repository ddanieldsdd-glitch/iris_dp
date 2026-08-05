import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_sync_bridge.dart';
import 'media_sync_providers.dart';

/// Enlaza servicios de media cloud con helpers estáticos (pegar, importar).
class MediaSyncBinder extends ConsumerStatefulWidget {
  final Widget child;

  const MediaSyncBinder({super.key, required this.child});

  @override
  ConsumerState<MediaSyncBinder> createState() => _MediaSyncBinderState();
}

class _MediaSyncBinderState extends ConsumerState<MediaSyncBinder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    MediaSyncBridge.bind(
      queue: ref.read(mediaUploadQueueProvider),
      ingestService: ref.read(mediaIngestServiceProvider),
    );
    ref.read(mediaUploadQueueProvider)?.notifyProgress();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mediaUploadQueueProvider, (_, __) => _bind());
    ref.listen(mediaIngestServiceProvider, (_, __) => _bind());
    return widget.child;
  }
}
