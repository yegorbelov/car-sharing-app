import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../models/rental_deal.dart';

/// Speech bubble with optional tail (tail only on last message in a group).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMine,
    this.showTail = true,
    this.compactBelow = false,
    this.compactEdgeTop = false,
    this.compactEdgeBottom = false,
    this.senderName,
    this.replyTo,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.onLongPress,
    this.onImageTap,
    this.onAttachmentLoaded,
  });

  final String text;
  final String time;
  final bool isMine;
  final bool showTail;
  final bool compactBelow;

  /// Smaller radius on top screen-edge corners (2nd+ in group).
  final bool compactEdgeTop;

  /// Smaller radius on bottom screen-edge corners (not last in group).
  final bool compactEdgeBottom;
  final String? senderName;
  final DealMessageReply? replyTo;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;
  final VoidCallback? onAttachmentLoaded;

  static const _mineFill = Color(0xFF111111);
  static const _bubblePad = EdgeInsets.fromLTRB(11, 7, 11, 9);
  static const _bubblePadMine = EdgeInsets.fromLTRB(11, 7, 9, 9);

  static const _mineText = Colors.white;

  bool get _hasAttachment => (attachmentUrl ?? '').isNotEmpty;

  bool get _hasText => text.trim().isNotEmpty;

  bool get _isImageAttachment =>
      _hasAttachment && (attachmentType ?? '') == 'image';

  EdgeInsets _textPad({required bool belowAttachment}) =>
      (isMine ? _bubblePadMine : _bubblePad).copyWith(
        top: belowAttachment
            ? 6
            : (isMine ? _bubblePadMine.top : _bubblePad.top),
      );

  /// Photo corners aligned with the bubble clipper (top-only when caption below).
  BorderRadius _imageClipRadius() {
    if (replyTo != null) {
      return const BorderRadius.all(Radius.circular(10));
    }

    const r = _IMessageBubbleClipper.radius;
    const rEdge = _IMessageBubbleClipper.radiusEdge;

    final topLeft = Radius.circular(!isMine && compactEdgeTop ? rEdge : r);
    final topRight = Radius.circular(isMine && compactEdgeTop ? rEdge : r);

    if (_hasText) {
      return BorderRadius.only(topLeft: topLeft, topRight: topRight);
    }

    final bottomLeft = Radius.circular(!isMine && compactEdgeBottom ? rEdge : r);
    final bottomRight = Radius.circular(isMine && compactEdgeBottom ? rEdge : r);
    return BorderRadius.only(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    final fill = isMine ? _mineFill : Colors.white;
    final onBubble = isMine ? _mineText : cs.onSurface;
    final muted = isMine
        ? _mineText.withValues(alpha: 0.62)
        : cs.onSurfaceVariant;
    final pad = isMine ? _bubblePadMine : _bubblePad;

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replyTo != null)
          Padding(
            padding: pad,
            child: _ReplyQuote(reply: replyTo!, isMine: isMine),
          ),
        if (_isImageAttachment)
          _AttachmentPreview(
            url: attachmentUrl!,
            type: 'image',
            name: attachmentName ?? 'Photo',
            isMine: isMine,
            maxBubbleWidth: maxW,
            edgeToEdge: true,
            borderRadius: _imageClipRadius(),
            time: !_hasText ? time : null,
            timeColor: muted,
            onTap: onImageTap,
            onLoaded: onAttachmentLoaded,
          ),
        if (_hasAttachment && !_isImageAttachment)
          Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AttachmentPreview(
                  url: attachmentUrl!,
                  type: attachmentType ?? 'file',
                  name: attachmentName ?? 'File',
                  isMine: isMine,
                  maxWidth: maxW - pad.left - pad.right,
                  edgeToEdge: false,
                  onLoaded: onAttachmentLoaded,
                ),
                if (!_hasText) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      time,
                      style: TextStyle(fontSize: 11, height: 1, color: muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (_hasText)
          Padding(
            padding: _textPad(belowAttachment: _hasAttachment),
            child: _BubbleTextWithTime(
              text: text,
              time: time,
              textColor: onBubble,
              timeColor: muted,
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 56 : 8,
        right: isMine ? 8 : 56,
        bottom: compactBelow ? 2 : 6,
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (senderName != null) ...[
            Padding(
              padding: EdgeInsets.only(
                left: isMine ? 0 : 4,
                right: isMine ? 4 : 0,
                bottom: 4,
              ),
              child: Text(
                senderName!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: GestureDetector(
                onLongPress: onLongPress,
                child: PhysicalShape(
                  clipper: _IMessageBubbleClipper(
                    isMine: isMine,
                    showTail: showTail,
                    compactEdgeTop: compactEdgeTop,
                    compactEdgeBottom: compactEdgeBottom,
                  ),
                  clipBehavior: Clip.antiAlias,
                  color: fill,
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.14),
                  child: inner,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text + timestamp on one line when short (iMessage / Telegram style).
class _BubbleTextWithTime extends StatelessWidget {
  const _BubbleTextWithTime({
    required this.text,
    required this.time,
    required this.textColor,
    required this.timeColor,
  });

  final String text;
  final String time;
  final Color textColor;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 2,
      children: [
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            height: 1.28,
            letterSpacing: -0.2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              color: timeColor,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-path bubble outline (iMessage-style corner tail).
class _IMessageBubbleClipper extends CustomClipper<Path> {
  const _IMessageBubbleClipper({
    required this.isMine,
    this.showTail = true,
    this.compactEdgeTop = false,
    this.compactEdgeBottom = false,
  });

  final bool isMine;
  final bool showTail;
  final bool compactEdgeTop;
  final bool compactEdgeBottom;

  static const radius = 17.0;
  static const radiusEdge = 6.0;

  static const _r = radius;
  static const _rEdge = radiusEdge;

  static Path buildPath(
    Size size,
    bool isMine, {
    bool showTail = true,
    bool compactEdgeTop = false,
    bool compactEdgeBottom = false,
  }) {
    final w = size.width;
    final h = size.height;

    final tr = isMine && compactEdgeTop ? _rEdge : _r;
    final br = isMine && compactEdgeBottom ? _rEdge : _r;
    final tl = !isMine && compactEdgeTop ? _rEdge : _r;
    final bl = !isMine && compactEdgeBottom ? _rEdge : _r;

    if (!showTail) {
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, w, h),
          topLeft: Radius.circular(tl),
          topRight: Radius.circular(tr),
          bottomLeft: Radius.circular(bl),
          bottomRight: Radius.circular(br),
        ),
      );
    }

    final path = Path();

    if (isMine) {
      path.moveTo(_r, 0);
      path.lineTo(w - tr, 0);
      path.arcToPoint(Offset(w, tr), radius: Radius.circular(tr));
      path.lineTo(w, h - _r - 6);
      path.lineTo(w, h);
      path.lineTo(w - 10, h - 2);
      path.lineTo(_r + 1, h - 2);
      path.arcToPoint(Offset(0, h - _r - 2), radius: const Radius.circular(_r));
      path.lineTo(0, _r);
      path.arcToPoint(Offset(_r, 0), radius: const Radius.circular(_r));
    } else {
      path.moveTo(tl, 0);
      path.lineTo(w - _r, 0);
      path.arcToPoint(Offset(w, _r), radius: const Radius.circular(_r));
      path.lineTo(w, h - _r - 2);
      path.arcToPoint(Offset(w - _r, h - 2), radius: const Radius.circular(_r));
      path.lineTo(tl + 1, h - 2);
      path.lineTo(0, h);
      path.lineTo(10, h - 2);
      path.lineTo(0, h - bl - 6);
      path.lineTo(0, tl);
      path.arcToPoint(Offset(tl, 0), radius: Radius.circular(tl));
    }
    path.close();
    return path;
  }

  @override
  Path getClip(Size size) => buildPath(
    size,
    isMine,
    showTail: showTail,
    compactEdgeTop: compactEdgeTop,
    compactEdgeBottom: compactEdgeBottom,
  );

  @override
  bool shouldReclip(covariant _IMessageBubbleClipper old) =>
      old.isMine != isMine ||
      old.showTail != showTail ||
      old.compactEdgeTop != compactEdgeTop ||
      old.compactEdgeBottom != compactEdgeBottom;
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.reply, required this.isMine});

  final DealMessageReply reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final accent = isMine ? const Color(0xFF6EA8FF) : const Color(0xFF111111);
    final bg = isMine
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFF0F2F8);
    final fg = isMine
        ? Colors.white.withValues(alpha: 0.92)
        : Theme.of(context).colorScheme.onSurface;
    final preview = reply.body.trim().isNotEmpty
        ? reply.body
        : switch (reply.attachmentType) {
            'image' => 'Photo',
            'file' => 'File',
            _ => 'Message',
          };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, height: 1.25, color: fg),
        ),
      ),
    );
  }
}

/// Decodes aspect ratio from bytes using a small thumbnail (fast, low memory).
Future<double> decodeImageAspectRatio(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  if (image.height == 0) return _ChatPhotoLayout.defaultAspect;
  return image.width / image.height;
}

/// Fits a photo into chat bounds while keeping aspect ratio (width / height).
class _ChatPhotoLayout {
  static const defaultAspect = 4 / 3;
  static const _maxHeight = 360.0;
  static const _minWidth = 180.0;

  static ({double width, double height}) displaySize({
    required double maxBubbleWidth,
    required double aspectRatio,
  }) {
    final maxW = (maxBubbleWidth * 0.88).clamp(_minWidth, 264.0);
    var w = maxW;
    var h = w / aspectRatio;
    if (h > _maxHeight) {
      h = _maxHeight;
      w = h * aspectRatio;
    }
    if (w > maxW) {
      w = maxW;
      h = w / aspectRatio;
    }
    return (width: w, height: h);
  }
}

class _ChatNetworkPhoto extends StatefulWidget {
  const _ChatNetworkPhoto({
    required this.url,
    required this.maxBubbleWidth,
    required this.isMine,
    this.borderRadius,
    this.time,
    this.timeColor,
    this.onTap,
    this.onLoaded,
  });

  final String url;
  final double maxBubbleWidth;
  final bool isMine;
  final BorderRadius? borderRadius;
  final String? time;
  final Color? timeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLoaded;

  @override
  State<_ChatNetworkPhoto> createState() => _ChatNetworkPhotoState();
}

class _ChatNetworkPhotoState extends State<_ChatNetworkPhoto> {
  late NetworkImage _provider;
  double _aspect = _ChatPhotoLayout.defaultAspect;
  bool _aspectResolved = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _provider = NetworkImage(widget.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attachAspectListener();
    });
  }

  @override
  void didUpdateWidget(covariant _ChatNetworkPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _provider = NetworkImage(widget.url);
      _aspect = _ChatPhotoLayout.defaultAspect;
      _aspectResolved = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _attachAspectListener();
      });
    }
  }

  @override
  void dispose() {
    _detachAspectListener();
    super.dispose();
  }

  void _detachAspectListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _attachAspectListener() {
    if (_aspectResolved) return;
    _detachAspectListener();
    // Small probe decode for aspect only — avoids loading 4MB+ into memory.
    _stream = _provider.resolve(
      const ImageConfiguration(size: Size(96, 96)),
    );
    _listener = ImageStreamListener((info, _) => _onImageReady(info.image));
    _stream!.addListener(_listener!);
  }

  void _onImageReady(ui.Image image) {
    if (!mounted || _aspectResolved || image.height == 0) return;
    _aspectResolved = true;
    _detachAspectListener();
    final next = image.width / image.height;
    final needsResize = (next - _aspect).abs() >= 0.02;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (needsResize) setState(() => _aspect = next);
      widget.onLoaded?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _ChatPhotoLayout.displaySize(
      maxBubbleWidth: widget.maxBubbleWidth,
      aspectRatio: _aspect,
    );
    final cacheW = (size.width * dpr).round().clamp(64, 720);
    final cacheH = (cacheW / _aspect).round().clamp(64, 960);
    final placeholder = widget.isMine
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFE8ECF4);
    final radius =
        widget.borderRadius ??
        const BorderRadius.all(Radius.circular(_IMessageBubbleClipper.radius));

    final frame = ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: placeholder),
            Image(
              image: ResizeImage(
                _provider,
                width: cacheW,
                height: cacheH,
              ),
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: widget.isMine ? Colors.white54 : Colors.black38,
                ),
              ),
            ),
            if (widget.time != null)
              Positioned(
                right: 6,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      widget.time!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: widget.timeColor ?? Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return frame;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: frame,
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.url,
    required this.type,
    required this.name,
    required this.isMine,
    this.maxWidth,
    this.maxBubbleWidth,
    this.edgeToEdge = false,
    this.borderRadius,
    this.time,
    this.timeColor,
    this.onTap,
    this.onLoaded,
  });

  final String url;
  final String type;
  final String name;
  final bool isMine;
  final double? maxWidth;
  final double? maxBubbleWidth;
  final bool edgeToEdge;
  final BorderRadius? borderRadius;
  final String? time;
  final Color? timeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLoaded;

  @override
  Widget build(BuildContext context) {
    if (type == 'image') {
      final bubbleW = maxBubbleWidth ?? maxWidth ?? 280.0;
      return _ChatNetworkPhoto(
        url: fullImageUrl(url),
        maxBubbleWidth: bubbleW,
        isMine: isMine,
        borderRadius: borderRadius,
        time: time,
        timeColor: timeColor,
        onTap: onTap,
        onLoaded: onLoaded,
      );
    }
    return _FileTile(name: name, isMine: isMine);
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.name, required this.isMine});

  final String name;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final bg = isMine
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFF0F2F8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: fg, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft gradient + dot pattern for the chat area.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9EDF8), Color(0xFFDDE3F2)],
        ),
      ),
      child: CustomPaint(painter: _DotPatternPainter(), child: child),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.07);
    const step = 22.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + 6, y + 6), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Date pill; [sticky] for pinned section headers.
class ChatDateChip extends StatelessWidget {
  const ChatDateChip({super.key, required this.label, this.sticky = false});

  final String label;
  final bool sticky;

  @override
  Widget build(BuildContext context) {
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: sticky ? 0.92 : 0.72),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    if (sticky) return chip;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(child: chip),
    );
  }
}

/// Empty state when there are no messages yet.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: cs.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Coordinate pickup, keys, and trip details here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo attachment preview above the composer (before send).
class ChatPhotoPreviewBar extends StatelessWidget {
  const ChatPhotoPreviewBar({
    super.key,
    required this.imageBytes,
    required this.onClose,
    this.onTapPreview,
  });

  final List<int> imageBytes;
  final VoidCallback onClose;
  final VoidCallback? onTapPreview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFF0F2F8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onTapPreview,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  Uint8List.fromList(imageBytes),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onTapPreview,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add a caption below, then send',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Remove photo',
            ),
          ],
        ),
      ),
    );
  }
}

/// Reply preview bar above the composer.
class ChatReplyBar extends StatelessWidget {
  const ChatReplyBar({
    super.key,
    required this.authorName,
    required this.preview,
    required this.onClose,
  });

  final String authorName;
  final String preview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFF0F2F8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Cancel reply',
            ),
          ],
        ),
      ),
    );
  }
}
