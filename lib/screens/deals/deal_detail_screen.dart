import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../models/rental_deal.dart';
import '../../services/deals_api.dart';
import '../../widgets/app_input.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_photo_gallery.dart';

/// Formats an ISO date/datetime string to "May 16, 2026".
String _fmtDate(String iso) {
  try {
    final d = DateTime.parse(iso.replaceAll(' ', 'T'));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso.length > 10 ? iso.substring(0, 10) : iso;
  }
}

/// Formats a datetime to "HH:mm".
String _fmtTime(String iso) {
  try {
    final d = DateTime.parse(iso.replaceAll(' ', 'T')).toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return iso.length > 16 ? iso.substring(11, 16) : iso;
  }
}

DateTime? _parseLocal(String iso) {
  try {
    return DateTime.parse(iso.replaceAll(' ', 'T')).toLocal();
  } catch (_) {
    return null;
  }
}

String _chatDateLabel(String iso) {
  final d = _parseLocal(iso);
  if (d == null) return iso;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

bool _showChatDateHeader(List<DealMessage> messages, int index) {
  if (index == 0) return true;
  final prev = _parseLocal(messages[index - 1].createdAt);
  final cur = _parseLocal(messages[index].createdAt);
  if (prev == null || cur == null) return false;
  return prev.year != cur.year || prev.month != cur.month || prev.day != cur.day;
}

bool _showChatSenderName(List<DealMessage> messages, int index) {
  if (index == 0 || _showChatDateHeader(messages, index)) return true;
  return messages[index - 1].senderId != messages[index].senderId;
}

class _ChatDayGroup {
  _ChatDayGroup({required this.label}) : indices = <int>[];

  final String label;
  final List<int> indices;
}

List<_ChatDayGroup> _groupMessagesByDay(List<DealMessage> messages) {
  final groups = <_ChatDayGroup>[];
  for (var i = 0; i < messages.length; i++) {
    final label = _chatDateLabel(messages[i].createdAt);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(_ChatDayGroup(label: label));
    }
    groups.last.indices.add(i);
  }
  return groups;
}

class _MessageBubbleGroup {
  _MessageBubbleGroup({required this.indices, required this.isMine});

  final List<int> indices;
  final bool isMine;
}

class _ChatListEntry {
  const _ChatListEntry({
    required this.messageIndex,
    required this.showTail,
    required this.compactBelow,
    required this.compactEdgeTop,
    required this.compactEdgeBottom,
    this.dayLabelForAnchor,
  });

  final int messageIndex;
  final bool showTail;
  final bool compactBelow;
  final bool compactEdgeTop;
  final bool compactEdgeBottom;
  final String? dayLabelForAnchor;
}

bool _shouldStartNewBubbleGroup(
  List<DealMessage> messages,
  int prevIndex,
  int curIndex,
) {
  final prev = messages[prevIndex];
  final cur = messages[curIndex];
  if (prev.senderId != cur.senderId) return true;
  final a = _parseLocal(prev.createdAt);
  final b = _parseLocal(cur.createdAt);
  if (a == null || b == null) return true;
  return b.difference(a).inMinutes > 5;
}

List<_MessageBubbleGroup> _groupBubbleIndices(
  List<int> dayIndices,
  List<DealMessage> messages,
  int? myId,
) {
  final groups = <_MessageBubbleGroup>[];
  for (final i in dayIndices) {
    final mine = myId == messages[i].senderId;
    if (groups.isEmpty || _shouldStartNewBubbleGroup(messages, groups.last.indices.last, i)) {
      groups.add(_MessageBubbleGroup(indices: [i], isMine: mine));
    } else {
      groups.last.indices.add(i);
    }
  }
  return groups;
}

String _messagePreview(DealMessage m) {
  if (m.body.trim().isNotEmpty) return m.body.trim();
  if (m.isImageAttachment) return 'Photo';
  if (m.isFileAttachment) return m.attachmentName ?? 'File';
  return 'Message';
}

class DealDetailScreen extends StatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final int dealId;

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  RentalDeal? _deal;
  List<DealMessage> _messages = [];
  bool _loading = true;
  String? _error;
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  AuthUser? _me;
  DealMessage? _replyTo;
  bool _sending = false;
  _PendingPhoto? _pendingPhoto;
  final _picker = ImagePicker();
  final _chatAreaKey = GlobalKey();
  final _dateChipKeys = <String, GlobalKey>{};
  Timer? _hideFloatingDateTimer;
  Timer? _scrollToBottomTimer;
  double _floatingDateOpacity = 0;
  String? _floatingDateLabel;
  bool _stickToBottom = true;
  bool _scrollAfterNextLayout = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _hideFloatingDateTimer?.cancel();
    _scrollToBottomTimer?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _dateChipKey(String label) =>
      _dateChipKeys.putIfAbsent(label, GlobalKey.new);

  bool _onChatScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _hideFloatingDateTimer?.cancel();
      if (notification is ScrollUpdateNotification && _scroll.hasClients) {
        final pos = _scroll.position;
        _stickToBottom = pos.pixels <= pos.minScrollExtent + 96;
      }
      _syncFloatingDateLabel();
      if (_floatingDateOpacity != 1) {
        setState(() => _floatingDateOpacity = 1);
      }
    }

    if (notification is ScrollEndNotification) {
      _hideFloatingDateTimer?.cancel();
      _hideFloatingDateTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _floatingDateOpacity = 0);
      });
    }
    return false;
  }

  void _syncFloatingDateLabel() {
    final areaBox = _chatAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (areaBox == null || !areaBox.hasSize) return;

    final anchorY = areaBox.localToGlobal(Offset.zero).dy + 52;
    String? label;
    double? bestY;

    for (final day in _groupMessagesByDay(_messages)) {
      final ctx = _dateChipKey(day.label).currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= anchorY && (bestY == null || y > bestY)) {
        bestY = y;
        label = day.label;
      }
    }

    label ??= _groupMessagesByDay(_messages).lastOrNull?.label;
    if (label != null && label != _floatingDateLabel) {
      setState(() => _floatingDateLabel = label);
    }
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _me = await AuthStorage.getUser();
      final d = await DealsApi.fetchDeal(widget.dealId);
      final m = await DealsApi.fetchMessages(widget.dealId);
      if (!mounted) return;
      setState(() {
        _deal = d;
        _messages = m;
        _loading = false;
      });
      _stickToBottom = true;
      _scheduleScrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// With [reverse: true], offset 0 = newest messages at the bottom.
  void _scrollToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.minScrollExtent;
    if ((_scroll.offset - target).abs() < 2) return;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _scheduleScrollToBottom({bool animated = false, bool force = false}) {
    if (!force && !_stickToBottom && !_scrollAfterNextLayout) return;
    _scrollToBottomTimer?.cancel();
    _scrollToBottomTimer = Timer(const Duration(milliseconds: 32), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animated: animated);
        _scrollAfterNextLayout = false;
      });
    });
  }

  Future<void> _reloadMessages({bool scrollToEnd = false}) async {
    try {
      final m = await DealsApi.fetchMessages(widget.dealId);
      if (!mounted) return;
      if (scrollToEnd) {
        _stickToBottom = true;
        _scrollAfterNextLayout = true;
      }
      setState(() => _messages = m);
      if (scrollToEnd) {
        _scheduleScrollToBottom(animated: true, force: true);
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_pendingPhoto != null) {
      await _sendPendingPhoto();
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final replyId = _replyTo?.id;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    _msgCtrl.clear();
    try {
      await DealsApi.postMessage(widget.dealId, body: text, replyToId: replyId);
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPendingPhoto() async {
    final pending = _pendingPhoto;
    if (pending == null || _sending) return;
    final caption = _msgCtrl.text.trim();
    final replyId = _replyTo?.id;
    setState(() {
      _sending = true;
      _pendingPhoto = null;
      _replyTo = null;
    });
    _msgCtrl.clear();
    try {
      await DealsApi.postMessageWithAttachment(
        widget.dealId,
        bytes: pending.bytes,
        filename: pending.filename,
        body: caption,
        replyToId: replyId,
      );
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingPhoto = pending);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment({
    List<int>? bytes,
    String? filePath,
    required String filename,
  }) async {
    if (_sending) return;
    if (bytes == null && (filePath == null || filePath.isEmpty)) return;

    final caption = _msgCtrl.text.trim();
    final replyId = _replyTo?.id;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    _msgCtrl.clear();
    try {
      await DealsApi.postMessageWithAttachment(
        widget.dealId,
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        body: caption,
        replyToId: replyId,
      );
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<ChatGalleryPhoto> _chatGalleryPhotos(RentalDeal d) {
    final photos = <ChatGalleryPhoto>[];
    for (final m in _messages) {
      if (!m.isImageAttachment) continue;
      final url = m.attachmentUrl;
      if (url == null || url.isEmpty) continue;
      final caption = m.body.trim();
      photos.add(
        ChatGalleryPhoto(
          messageId: m.id,
          url: url,
          caption: caption.isEmpty ? null : caption,
          time: _fmtTime(m.createdAt),
          senderName: _senderLabel(m, d),
        ),
      );
    }
    return photos;
  }

  void _openChatGallery(DealMessage message, RentalDeal d) {
    final photos = _chatGalleryPhotos(d);
    final index = photos.indexWhere((p) => p.messageId == message.id);
    if (index < 0) return;
    showChatPhotoGallery(context, photos: photos, initialIndex: index);
  }

  void _showPhotoPreviewDialog(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final name = file.name.trim().isNotEmpty ? file.name : 'photo.jpg';
    final aspect = await decodeImageAspectRatio(bytes);
    setState(() {
      _pendingPhoto = _PendingPhoto(
        bytes: bytes,
        filename: name,
        aspectRatio: aspect,
      );
    });
    _scheduleScrollToBottom(animated: false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.single;
    final name = picked.name.trim().isNotEmpty ? picked.name : 'file';
    if (picked.bytes != null) {
      await _sendAttachment(bytes: picked.bytes, filename: name);
    } else if (picked.path != null) {
      await _sendAttachment(filePath: picked.path, filename: name);
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startReply(DealMessage m, RentalDeal d) {
    setState(() => _replyTo = m);
  }

  String _senderLabel(DealMessage m, RentalDeal d) {
    if (m.senderId == d.ownerId) return d.ownerName;
    return d.renterName;
  }

  List<_ChatListEntry> _chatEntries(AuthUser? me) {
    final entries = <_ChatListEntry>[];
    for (final day in _groupMessagesByDay(_messages)) {
      final bubbleGroups = _groupBubbleIndices(day.indices, _messages, me?.id);
      var firstOfDay = true;
      for (final bg in bubbleGroups) {
        for (var j = 0; j < bg.indices.length; j++) {
          final isLast = j == bg.indices.length - 1;
          entries.add(_ChatListEntry(
            messageIndex: bg.indices[j],
            showTail: isLast,
            compactBelow: !isLast,
            compactEdgeTop: j > 0,
            compactEdgeBottom: !isLast,
            dayLabelForAnchor: firstOfDay ? day.label : null,
          ));
          firstOfDay = false;
        }
      }
    }
    return entries;
  }

  List<Widget> _chatSlivers(RentalDeal d, AuthUser? me) {
    final entries = _chatEntries(me);
    final count = entries.length;
    return [
      const SliverPadding(padding: EdgeInsets.only(bottom: 10)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, idx) {
              // Newest at idx 0 → sits at the bottom (reverse scroll).
              final e = entries[count - 1 - idx];
              final i = e.messageIndex;
              final m = _messages[i];
              final mine = me?.id == m.senderId;
              final senderName = !mine && _showChatSenderName(_messages, i)
                  ? _senderLabel(m, d)
                  : null;
              final bubble = ChatBubble(
                text: m.body,
                time: _fmtTime(m.createdAt),
                isMine: mine,
                showTail: e.showTail,
                compactBelow: e.compactBelow,
                compactEdgeTop: e.compactEdgeTop,
                compactEdgeBottom: e.compactEdgeBottom,
                senderName: senderName,
                replyTo: m.replyTo,
                attachmentUrl: m.attachmentUrl,
                attachmentType: m.attachmentType,
                attachmentName: m.attachmentName,
                onLongPress: () => _startReply(m, d),
                onImageTap: m.isImageAttachment ? () => _openChatGallery(m, d) : null,
              );
              if (e.dayLabelForAnchor == null) return bubble;
              return KeyedSubtree(
                key: _dateChipKey(e.dayLabelForAnchor!),
                child: bubble,
              );
            },
            childCount: count,
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(top: 12)),
    ];
  }

  Widget _buildChatList(RentalDeal d, AuthUser? me) {
    if (_messages.isEmpty) return const ChatEmptyState();

    _floatingDateLabel ??= _groupMessagesByDay(_messages).last.label;

    return Stack(
      key: _chatAreaKey,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onChatScroll,
          child: CustomScrollView(
            controller: _scroll,
            reverse: true,
            cacheExtent: 800,
            slivers: _chatSlivers(d, me),
          ),
        ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _floatingDateOpacity,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Center(
                child: _floatingDateLabel == null
                    ? const SizedBox.shrink()
                    : ChatDateChip(
                        label: _floatingDateLabel!,
                        sticky: true,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String s) {
    return switch (s) {
      'pending_owner' => 'Waiting for owner approval',
      'active' => 'Active — trip in progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => s,
    };
  }

  Color _statusColor(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    return switch (s) {
      'pending_owner' => cs.tertiary,
      'active' => cs.primary,
      'completed' => cs.secondary,
      'cancelled' => cs.error,
      _ => cs.onSurface,
    };
  }

  Future<void> _mutate(Future<void> Function() call) async {
    try {
      await call();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DealsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _boot, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final d = _deal!;
    final me = _me;
    final hold = (d.holdAmountCents / 100).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(title: Text(d.vehicleTitle)),
      body: Column(
        children: [
          // Deal summary card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: _statusColor(context, d.status)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusLabel(d.status),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Hold \$$hold', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          '${d.dayCount} days',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtDate(d.startDate)} → ${_fmtDate(d.endDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ParticipantCell(
                            icon: Icons.directions_car_rounded,
                            label: 'Renter',
                            name: d.renterName,
                            isMe: me?.id == d.renterId,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ParticipantCell(
                            icon: Icons.key_rounded,
                            label: 'Owner',
                            name: d.ownerName,
                            isMe: me?.id == d.ownerId,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          if (d.status == 'pending_owner' && d.isOwner) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mutate(() => DealsApi.accept(d.id)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mutate(() => DealsApi.decline(d.id)),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (d.status == 'pending_owner' && d.isRenter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _mutate(() => DealsApi.renterCancel(d.id)),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Cancel & refund hold'),
                ),
              ),
            ),
          if (d.status == 'active' && d.isOwner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _mutate(() => DealsApi.complete(d.id)),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Complete trip & release payout'),
                ),
              ),
            ),

          // Chat
          Expanded(
            child: ChatWallpaper(child: _buildChatList(d, me)),
          ),

          if (_replyTo != null)
            ChatReplyBar(
              authorName: _senderLabel(_replyTo!, d),
              preview: _messagePreview(_replyTo!),
              onClose: () => setState(() => _replyTo = null),
            ),

          if (_pendingPhoto != null)
            ChatPhotoPreviewBar(
              imageBytes: _pendingPhoto!.bytes,
              onClose: () => setState(() => _pendingPhoto = null),
              onTapPreview: () => _showPhotoPreviewDialog(_pendingPhoto!.bytes),
            ),

          // Message input
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _sending ? null : _showAttachSheet,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      tooltip: 'Attach',
                      iconSize: 28,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: AppInputs.chat(context).copyWith(
                          fillColor: const Color(0xFFF0F2F8),
                          filled: true,
                          hintText: _pendingPhoto != null
                              ? 'Caption (optional)…'
                              : (_replyTo != null ? 'Reply…' : 'Message…'),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 0,
                      child: InkWell(
                        onTap: (_sending ||
                                (_pendingPhoto == null &&
                                    _msgCtrl.text.trim().isEmpty))
                            ? null
                            : _send,
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: _sending
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPhoto {
  const _PendingPhoto({
    required this.bytes,
    required this.filename,
    required this.aspectRatio,
  });

  final Uint8List bytes;
  final String filename;
  final double aspectRatio;
}

class _ParticipantCell extends StatelessWidget {
  const _ParticipantCell({
    required this.icon,
    required this.label,
    required this.name,
    required this.isMe,
  });

  final IconData icon;
  final String label;
  final String name;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(
                isMe ? '$name (you)' : name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
