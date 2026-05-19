import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_config.dart';

/// One image in the deal chat gallery (chronological order).
class ChatGalleryPhoto {
  const ChatGalleryPhoto({
    required this.messageId,
    required this.url,
    this.caption,
    required this.time,
    required this.senderName,
  });

  final int messageId;
  final String url;
  final String? caption;
  final String time;
  final String senderName;

  String get imageUrl => fullImageUrl(url);
}

/// Full-screen viewer with horizontal swipe through all chat photos.
Future<void> showChatPhotoGallery(
  BuildContext context, {
  required List<ChatGalleryPhoto> photos,
  required int initialIndex,
}) {
  if (photos.isEmpty) return Future.value();
  final index = initialIndex.clamp(0, photos.length - 1);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _ChatPhotoGalleryPage(photos: photos, initialIndex: index),
        );
      },
    ),
  );
}

class _ChatPhotoGalleryPage extends StatefulWidget {
  const _ChatPhotoGalleryPage({
    required this.photos,
    required this.initialIndex,
  });

  final List<ChatGalleryPhoto> photos;
  final int initialIndex;

  @override
  State<_ChatPhotoGalleryPage> createState() => _ChatPhotoGalleryPageState();
}

class _ChatPhotoGalleryPageState extends State<_ChatPhotoGalleryPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final hasCaption = (photo.caption ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final item = widget.photos[i];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.85,
                  maxScale: 4,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Close',
                      ),
                      Expanded(
                        child: Text(
                          widget.photos.length > 1
                              ? '${_index + 1} / ${widget.photos.length}'
                              : photo.senderName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.photos.length > 1)
                        Text(
                          photo.senderName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      if (hasCaption) ...[
                        if (widget.photos.length > 1) const SizedBox(height: 4),
                        Text(
                          photo.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        photo.time,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
