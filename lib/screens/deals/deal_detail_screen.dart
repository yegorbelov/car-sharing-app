import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth_storage.dart';
import '../../core/user_messages.dart';
import '../../models/auth_user.dart';
import '../../models/dispute.dart';
import '../../models/rental_deal.dart';
import '../../services/chat_attachment_preview.dart';
import '../../services/deal_chat_socket.dart';
import '../../services/deals_api.dart';
import '../../widgets/app_snackbar.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_photo_gallery.dart';

/// Formats an ISO date/datetime string to "May 16, 2026".
String _fmtDate(String iso) {
  try {
    final d = DateTime.parse(iso.replaceAll(' ', 'T'));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

bool _showChatDateHeader(List<DealMessage> messages, int index) {
  if (index == 0) return true;
  final prev = _parseLocal(messages[index - 1].createdAt);
  final cur = _parseLocal(messages[index].createdAt);
  if (prev == null || cur == null) return false;
  return prev.year != cur.year ||
      prev.month != cur.month ||
      prev.day != cur.day;
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
    if (groups.isEmpty ||
        _shouldStartNewBubbleGroup(messages, groups.last.indices.last, i)) {
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
  RentalDispute? _dispute;
  List<DealMessage> _messages = [];
  bool _loading = true;
  String? _error;
  final _msgCtrl = TextEditingController();
  final _msgFocus = FocusNode();
  final _scroll = ScrollController();
  AuthUser? _me;
  DealMessage? _replyTo;
  bool _sending = false;
  bool _canSend = false;
  _PendingPhoto? _pendingPhoto;
  final _picker = ImagePicker();
  final _chatAreaKey = GlobalKey();
  final _dateChipKeys = <String, GlobalKey>{};
  final _messageKeys = <int, GlobalKey>{};
  Timer? _hideFloatingDateTimer;
  Timer? _scrollToBottomTimer;
  Timer? _flashMessageTimer;
  DealChatSocket? _chatSocket;
  int? _flashMessageId;
  double _floatingDateOpacity = 0;
  String? _floatingDateLabel;
  static const _bottomSlack = 50.0;

  bool _stickToBottom = true;
  bool _showJumpToBottom = false;
  bool _dealInfoExpanded = false;
  bool _scrollAfterNextLayout = false;
  double? _scrollPixelsBeforeMessageUpdate;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onMessageTextChanged);
    _boot();
  }

  @override
  void dispose() {
    _chatSocket?.dispose();
    _hideFloatingDateTimer?.cancel();
    _scrollToBottomTimer?.cancel();
    _flashMessageTimer?.cancel();
    _msgCtrl.removeListener(_onMessageTextChanged);
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMessageTextChanged() {
    final can = _pendingPhoto != null || _msgCtrl.text.trim().isNotEmpty;
    if (can == _canSend) return;
    setState(() => _canSend = can);
  }

  void _startChatSocket() {
    _chatSocket?.dispose();
    _chatSocket = DealChatSocket(
      dealId: widget.dealId,
      onNewMessage: _onChatSocketMessage,
      onUnauthorized: DealsApi.onUnauthorized,
    )..connect();
  }

  void _onChatSocketMessage() {
    if (!mounted || _sending) return;
    unawaited(_reloadMessages(silent: true));
  }

  Future<void> _openAttachment(DealMessage message) async {
    final url = message.attachmentUrl;
    if (url == null || url.isEmpty || !mounted) return;
    await previewChatAttachment(
      context,
      attachmentUrl: url,
      attachmentName: message.attachmentName,
      attachmentType: message.attachmentType,
    );
  }

  bool _isPreviewableFile(DealMessage m) =>
      m.hasAttachment && !m.isImageAttachment;

  void _showSnack(String message) {
    if (!mounted) return;
    context.showAppSnackBar(message);
  }

  void _dismissMessageKeyboard() {
    if (_msgFocus.hasFocus) _msgFocus.unfocus();
  }

  GlobalKey _dateChipKey(String label) =>
      _dateChipKeys.putIfAbsent(label, GlobalKey.new);

  GlobalKey _messageKey(int messageId) =>
      _messageKeys.putIfAbsent(messageId, GlobalKey.new);

  int? _indexOfMessage(int messageId) {
    final i = _messages.indexWhere((m) => m.id == messageId);
    return i < 0 ? null : i;
  }

  void _flashMessage(int messageId) {
    _flashMessageTimer?.cancel();
    setState(() => _flashMessageId = messageId);
    _flashMessageTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flashMessageId = null);
    });
  }

  Future<void> _scrollToMessage(int messageId) async {
    final targetIdx = _indexOfMessage(messageId);
    if (targetIdx == null) return;

    final key = _messageKey(messageId);
    const step = 320.0;

    for (var attempt = 0; attempt < 18; attempt++) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final ctx = key.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.38,
        );
        if (!mounted) return;
        _flashMessage(messageId);
        _updateBottomProximity();
        return;
      }

      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final max = pos.maxScrollExtent;
      final estimatedIdx = max > 0
          ? (pos.pixels / max * (_messages.length - 1)).round()
          : _messages.length - 1;

      final nextOffset = targetIdx > estimatedIdx
          ? (pos.pixels - step).clamp(pos.minScrollExtent, max)
          : (pos.pixels + step).clamp(pos.minScrollExtent, max);
      if (nextOffset == pos.pixels) break;
      _scroll.jumpTo(nextOffset);
    }
  }

  void _updateBottomProximity() {
    if (!_scroll.hasClients || _messages.isEmpty) {
      if (_showJumpToBottom || !_stickToBottom) {
        setState(() {
          _showJumpToBottom = false;
          _stickToBottom = true;
        });
      }
      return;
    }
    final pos = _scroll.position;
    final nearBottom = pos.pixels <= pos.minScrollExtent + _bottomSlack;
    if (_stickToBottom == nearBottom && _showJumpToBottom == !nearBottom) {
      return;
    }
    setState(() {
      _stickToBottom = nearBottom;
      _showJumpToBottom = !nearBottom;
    });
  }

  void _jumpToLatest() {
    setState(() {
      _stickToBottom = true;
      _showJumpToBottom = false;
    });
    _scrollToBottom(animated: true);
  }

  bool _onChatScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _hideFloatingDateTimer?.cancel();
      if (notification is ScrollUpdateNotification) {
        _updateBottomProximity();
      }
      _syncFloatingDateLabel();
      if (_floatingDateOpacity != 1) {
        setState(() => _floatingDateOpacity = 1);
      }
    }

    if (notification is ScrollEndNotification) {
      _updateBottomProximity();
      _hideFloatingDateTimer?.cancel();
      _hideFloatingDateTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _floatingDateOpacity = 0);
      });
    }
    return false;
  }

  void _syncFloatingDateLabel() {
    final areaBox =
        _chatAreaKey.currentContext?.findRenderObject() as RenderBox?;
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

  void _openUserProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
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
      RentalDispute? dispute;
      try {
        dispute = await DealsApi.fetchDealDispute(widget.dealId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _deal = d;
        _dispute = dispute;
        _messages = m;
        _loading = false;
      });
      _stickToBottom = true;
      _scheduleScrollToBottom(animated: false);
      _startChatSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  void _captureScrollBeforeMessageUpdate() {
    if (_scroll.hasClients) {
      _scrollPixelsBeforeMessageUpdate = _scroll.position.pixels;
    }
  }

  bool _wasAtBottomBeforeMessageUpdate() {
    final before = _scrollPixelsBeforeMessageUpdate;
    _scrollPixelsBeforeMessageUpdate = null;
    if (before == null || !_scroll.hasClients) return _stickToBottom;
    return before <= _scroll.position.minScrollExtent + _bottomSlack;
  }

  static const _scrollAnimDuration = Duration(milliseconds: 320);
  static const _scrollAnimCurve = Curves.easeOutCubic;

  /// With [reverse: true], offset 0 = newest messages at the bottom.
  void _scrollToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = pos.minScrollExtent;
    final from = pos.pixels;
    if (!animated) {
      if ((from - target).abs() > 1) pos.jumpTo(target);
      return;
    }
    if ((from - target).abs() < 2) return;
    pos.animateTo(
      target,
      duration: _scrollAnimDuration,
      curve: _scrollAnimCurve,
    );
  }

  /// When already at the bottom, [ensureVisible] does nothing — nudge up by the
  /// new bubble height, then animate back to the end so the message slides in.
  Future<bool> _revealNewMessageAtBottom() async {
    if (!_scroll.hasClients || _messages.isEmpty) return false;
    final pos = _scroll.position;
    final target = pos.minScrollExtent;
    if (pos.pixels > target + 2) return false;

    var reveal = 40.0;
    final ctx = _messageKey(_messages.last.id).currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) reveal = box.size.height + 4;
    }

    final start = (target + reveal).clamp(target, pos.maxScrollExtent);
    if ((start - pos.pixels).abs() < 2) return false;

    pos.jumpTo(start);
    await pos.animateTo(
      target,
      duration: _scrollAnimDuration,
      curve: _scrollAnimCurve,
    );
    return true;
  }

  Future<void> _scrollToLatest({
    bool animated = false,
    bool revealIfWasAtBottom = false,
  }) async {
    if (!_scroll.hasClients || _messages.isEmpty) return;

    if (animated) {
      for (var attempt = 0; attempt < 4; attempt++) {
        await Future<void>.delayed(Duration.zero);
        if (!mounted || !_scroll.hasClients) return;

        final pos = _scroll.position;
        final atBottom = pos.pixels <= pos.minScrollExtent + 2;

        if (revealIfWasAtBottom && atBottom) {
          if (await _revealNewMessageAtBottom()) {
            _updateBottomProximity();
            return;
          }
        }

        if (!atBottom) {
          final ctx = _messageKey(_messages.last.id).currentContext;
          if (ctx != null) {
            await Scrollable.ensureVisible(
              ctx,
              duration: _scrollAnimDuration,
              curve: _scrollAnimCurve,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
            _updateBottomProximity();
            return;
          }
        }
      }
    }

    _scrollToBottom(animated: animated);
    _updateBottomProximity();
  }

  void _scheduleScrollToBottom({
    bool animated = false,
    bool force = false,
    bool revealIfWasAtBottom = false,
  }) {
    if (!force && !_stickToBottom && !_scrollAfterNextLayout) return;
    _scrollToBottomTimer?.cancel();
    _scrollToBottomTimer = Timer(const Duration(milliseconds: 32), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _scrollToLatest(
          animated: animated,
          revealIfWasAtBottom: revealIfWasAtBottom,
        );
        _scrollAfterNextLayout = false;
      });
    });
  }

  bool _messagesDiffer(List<DealMessage> a, List<DealMessage> b) {
    if (a.length != b.length) return true;
    if (a.isEmpty) return false;
    return a.last.id != b.last.id;
  }

  Future<void> _reloadMessages({
    bool scrollToEnd = false,
    bool silent = false,
  }) async {
    try {
      if (scrollToEnd || _stickToBottom) {
        _captureScrollBeforeMessageUpdate();
      }
      final m = await DealsApi.fetchMessages(widget.dealId);
      if (!mounted) return;
      final changed = _messagesDiffer(_messages, m);
      if (!scrollToEnd && !changed) return;
      final wasAtBottom = _wasAtBottomBeforeMessageUpdate();
      if (scrollToEnd) {
        _stickToBottom = true;
        _scrollAfterNextLayout = true;
      }
      setState(() => _messages = m);
      if (scrollToEnd ||
          (wasAtBottom && changed) ||
          (_stickToBottom && changed)) {
        _scheduleScrollToBottom(
          animated: true,
          force: true,
          revealIfWasAtBottom: wasAtBottom,
        );
      }
    } catch (e) {
      if (!silent) _showSnack(userFacingError(e));
    }
  }

  Future<void> _send() async {
    if (_pendingPhoto != null) {
      await _sendPendingPhoto();
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final replyId = _replyTo?.id;
    final savedReply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    try {
      await DealsApi.postMessage(widget.dealId, body: text, replyToId: replyId);
      if (!mounted) return;
      _msgCtrl.clear();
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      _msgCtrl.text = text;
      setState(() => _replyTo = savedReply);
      _showSnack(userFacingError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPendingPhoto() async {
    final pending = _pendingPhoto;
    if (pending == null || _sending) return;
    final caption = _msgCtrl.text.trim();
    final replyId = _replyTo?.id;
    final savedReply = _replyTo;
    setState(() {
      _sending = true;
      _pendingPhoto = null;
      _replyTo = null;
    });
    try {
      await DealsApi.postMessageWithAttachment(
        widget.dealId,
        bytes: pending.bytes,
        filename: pending.filename,
        body: caption,
        replyToId: replyId,
      );
      if (!mounted) return;
      _msgCtrl.clear();
      _onMessageTextChanged();
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingPhoto = pending;
        _replyTo = savedReply;
      });
      if (caption.isNotEmpty) _msgCtrl.text = caption;
      _onMessageTextChanged();
      _showSnack(userFacingError(e));
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
    final savedReply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    try {
      await DealsApi.postMessageWithAttachment(
        widget.dealId,
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        body: caption,
        replyToId: replyId,
      );
      if (!mounted) return;
      _msgCtrl.clear();
      _onMessageTextChanged();
      await _reloadMessages(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _replyTo = savedReply);
      if (caption.isNotEmpty) _msgCtrl.text = caption;
      _showSnack(userFacingError(e));
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
    _onMessageTextChanged();
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
    _scrollToMessage(m.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _msgFocus.requestFocus();
    });
  }

  String _senderLabel(DealMessage m, RentalDeal d) {
    if (m.senderId == d.ownerId) return d.ownerName;
    return d.renterName;
  }

  String _opponentName(RentalDeal d) => d.isRenter ? d.ownerName : d.renterName;

  List<_ChatListEntry> _chatEntries(AuthUser? me) {
    final entries = <_ChatListEntry>[];
    for (final day in _groupMessagesByDay(_messages)) {
      final bubbleGroups = _groupBubbleIndices(day.indices, _messages, me?.id);
      var firstOfDay = true;
      for (final bg in bubbleGroups) {
        for (var j = 0; j < bg.indices.length; j++) {
          final isLast = j == bg.indices.length - 1;
          entries.add(
            _ChatListEntry(
              messageIndex: bg.indices[j],
              showTail: isLast,
              compactBelow: !isLast,
              compactEdgeTop: j > 0,
              compactEdgeBottom: !isLast,
              dayLabelForAnchor: firstOfDay ? day.label : null,
            ),
          );
          firstOfDay = false;
        }
      }
    }
    return entries;
  }

  /// Top inset for collapsed deal overlay only — expanding deal draws over chat.
  double _chatTopInset(RentalDeal d) {
    var h = 104.0;
    if (d.status == 'pending_owner' && d.isOwner) h += 60;
    if (d.status == 'pending_owner' && d.isRenter) h += 52;
    if (d.status == 'active' && d.isOwner) h += 52;
    if (d.status == 'disputed' || _dispute != null) h += 56;
    if (_canOpenDispute(d)) h += 48;
    return h;
  }

  bool _canOpenDispute(RentalDeal d) {
    if (_dispute != null && _dispute!.isOpen) return false;
    if (d.status != 'active' && d.status != 'completed') return false;
    return _dispute == null;
  }

  List<Widget> _chatSlivers(
    RentalDeal d,
    AuthUser? me, {
    required double topInset,
  }) {
    final entries = _chatEntries(me);
    final count = entries.length;
    // reverse: true — first sliver = visual bottom (above input), last = visual top.
    return [
      const SliverPadding(padding: EdgeInsets.only(bottom: 6)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, idx) {
            // Newest at idx 0 → sits at the bottom (reverse scroll).
            final e = entries[count - 1 - idx];
            final i = e.messageIndex;
            final m = _messages[i];
            final mine = me?.id == m.senderId;
            final senderName = !mine && _showChatSenderName(_messages, i)
                ? _senderLabel(m, d)
                : null;
            final highlighted = _flashMessageId == m.id;
            final bubble = KeyedSubtree(
              key: _messageKey(m.id),
              child: ChatBubble(
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
                highlighted: highlighted,
                onLongPress: () => _startReply(m, d),
                onReplyTap: m.replyTo != null
                    ? () => _scrollToMessage(m.replyTo!.id)
                    : null,
                onImageTap: m.isImageAttachment
                    ? () => _openChatGallery(m, d)
                    : null,
                onFileTap: _isPreviewableFile(m)
                    ? () => _openAttachment(m)
                    : null,
              ),
            );
            if (e.dayLabelForAnchor == null) return bubble;
            return KeyedSubtree(
              key: _dateChipKey(e.dayLabelForAnchor!),
              child: bubble,
            );
          }, childCount: count),
        ),
      ),
      SliverPadding(padding: EdgeInsets.only(top: topInset + 8)),
    ];
  }

  Widget _buildChatList(
    RentalDeal d,
    AuthUser? me, {
    required double topInset,
  }) {
    if (_messages.isEmpty) {
      return _ShortTapKeyboardDismiss(
        onDismiss: _dismissMessageKeyboard,
        child: const ChatEmptyState(),
      );
    }

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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            slivers: _chatSlivers(d, me, topInset: topInset),
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
                    : ChatDateChip(label: _floatingDateLabel!, sticky: true),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 10,
          child: IgnorePointer(
            ignoring: !_showJumpToBottom,
            child: AnimatedOpacity(
              opacity: _showJumpToBottom ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: _showJumpToBottom ? 1 : 0.85,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _jumpToLatest,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    tooltip: 'Latest messages',
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
      'disputed' => 'Dispute under review',
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
      'disputed' => const Color(0xFFE65100),
      _ => cs.onSurface,
    };
  }

  Future<void> _openDispute(RentalDeal d) async {
    List<DisputeReason> reasons;
    try {
      reasons = await DealsApi.fetchDisputeReasons();
    } catch (e) {
      if (!mounted) return;
      _showSnack(userFacingError(e));
      return;
    }
    if (reasons.isEmpty) return;

    var reasonCode = reasons.first.code;
    final descCtrl = TextEditingController();
    Uint8List? photoBytes;
    String? photoPath;
    String photoName = 'evidence.jpg';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Open dispute'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Funds stay on hold until an arbitrator resolves the case. '
                  'Trip actions are paused.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reasonCode,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.code,
                          child: Text(r.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDlg(() => reasonCode = val ?? reasonCode),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText: 'At least 10 characters',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final x = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (x == null) return;
                    final bytes = await x.readAsBytes();
                    setDlg(() {
                      photoBytes = bytes;
                      photoPath = x.path;
                      photoName = x.name;
                    });
                  },
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(
                    photoBytes != null ? 'Photo attached' : 'Add photo (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final description = descCtrl.text.trim();
    descCtrl.dispose();
    if (ok != true || !mounted) return;
    if (description.length < 10) {
      _showSnack('Please describe the issue (at least 10 characters).');
      return;
    }
    try {
      final dispute = await DealsApi.openDispute(
        d.id,
        reasonCode: reasonCode,
        description: description,
        photoPath: photoPath,
        photoBytes: photoBytes,
        photoFilename: photoName,
      );
      if (!mounted) return;
      setState(() {
        _dispute = dispute;
        _deal = RentalDeal(
          id: d.id,
          vehicleId: d.vehicleId,
          vehicleTitle: d.vehicleTitle,
          renterId: d.renterId,
          ownerId: d.ownerId,
          renterName: d.renterName,
          ownerName: d.ownerName,
          status: 'disputed',
          holdAmountCents: d.holdAmountCents,
          myRole: d.myRole,
          dayCount: d.dayCount,
          startDate: d.startDate,
          endDate: d.endDate,
          createdAt: d.createdAt,
        );
      });
      context.showAppSnackBar(
        'Dispute submitted for review.',
        kind: AppSnackBarKind.success,
      );
    } on DealsApiException catch (e) {
      if (!mounted) return;
      _showSnack(mapDealActionError(e.code));
    } catch (e) {
      if (!mounted) return;
      _showSnack(userFacingError(e));
    }
  }

  Future<void> _confirmMutate({
    required String title,
    required String message,
    required Future<void> Function() call,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _mutate(call);
  }

  Future<void> _mutate(Future<void> Function() call) async {
    try {
      await call();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DealsApiException catch (e) {
      if (!mounted) return;
      _showSnack(mapDealActionError(e.code));
    } catch (e) {
      if (!mounted) return;
      _showSnack(userFacingError(e));
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

    final opponent = _opponentName(d);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.vehicleTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              opponent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _ShortTapKeyboardDismiss(
              onDismiss: _dismissMessageKeyboard,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: ChatWallpaper(
                      child: _buildChatList(d, me, topInset: _chatTopInset(d)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildDealOverlay(context, d, me, hold, cs),
                  ),
                ],
              ),
            ),
          ),

          ColoredBox(
            color: ChatWallpaper.backgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyTo != null)
                  ChatReplyBar(
                    authorName: _senderLabel(_replyTo!, d),
                    preview: _messagePreview(_replyTo!),
                    onTap: () => _scrollToMessage(_replyTo!.id),
                    onClose: () => setState(() => _replyTo = null),
                  ),
                if (_pendingPhoto != null)
                  ChatPhotoPreviewBar(
                    imageBytes: _pendingPhoto!.bytes,
                    onClose: () {
                      setState(() => _pendingPhoto = null);
                      _onMessageTextChanged();
                    },
                    onTapPreview: () =>
                        _showPhotoPreviewDialog(_pendingPhoto!.bytes),
                  ),
                ChatComposer(
                  controller: _msgCtrl,
                  focusNode: _msgFocus,
                  hintText: _pendingPhoto != null
                      ? 'Caption (optional)…'
                      : (_replyTo != null ? 'Reply…' : 'Message…'),
                  canSend: _canSend,
                  sending: _sending,
                  onSend: _send,
                  onAttach: _showAttachSheet,
                  onChanged: (_) => _onMessageTextChanged(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealOverlay(
    BuildContext context,
    RentalDeal d,
    AuthUser? me,
    String hold,
    ColorScheme cs,
  ) {
    return Material(
      color: cs.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(
                        () => _dealInfoExpanded = !_dealInfoExpanded,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: _statusColor(context, d.status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusLabel(d.status),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            AnimatedRotation(
                              turns: _dealInfoExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: Icon(
                                Icons.expand_more_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_dealInfoExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Text(
                        '${_fmtDate(d.startDate)} → ${_fmtDate(d.endDate)} · '
                        '${d.dayCount} days · Hold \$$hold',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _dealInfoExpanded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Hold \$$hold',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${d.dayCount} days',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fmtDate(d.startDate)} → ${_fmtDate(d.endDate)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
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
                                        onTap: () => _openUserProfile(d.renterId),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ParticipantCell(
                                        icon: Icons.key_rounded,
                                        label: 'Owner',
                                        name: d.ownerName,
                                        isMe: me?.id == d.ownerId,
                                        onTap: () => _openUserProfile(d.ownerId),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
          if (d.status == 'pending_owner' && d.isOwner) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmMutate(
                        title: 'Accept rental?',
                        message:
                            'The renter\'s security hold stays in place until the trip completes.',
                        call: () => DealsApi.accept(d.id),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmMutate(
                        title: 'Decline request?',
                        message:
                            'The hold will be released back to the renter.',
                        call: () => DealsApi.decline(d.id),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (d.status == 'pending_owner' && d.isRenter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmMutate(
                    title: 'Cancel request?',
                    message:
                        'Your security hold will be refunded to your wallet.',
                    call: () => DealsApi.renterCancel(d.id),
                  ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Cancel & refund hold'),
                ),
              ),
            ),
          if (d.status == 'active' && d.isOwner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _confirmMutate(
                    title: 'Complete trip?',
                    message:
                        'Funds will be released to you and the rental will be marked completed.',
                    call: () => DealsApi.complete(d.id),
                  ),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Complete trip & release payout'),
                ),
              ),
            ),
          if (_dispute != null && (_dispute!.isOpen || d.status == 'disputed'))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.gavel_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dispute!.isOpen
                                  ? 'Dispute open — arbitration in progress'
                                  : 'Dispute resolved',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dispute!.reasonLabel}: ${_dispute!.description}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_dispute!.isResolved &&
                          (_dispute!.resolutionNote?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Resolution: ${_dispute!.resolutionNote}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (_canOpenDispute(d))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openDispute(d),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Open dispute'),
                ),
              ),
            ),
          const SizedBox(height: 8),
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

/// Dismisses keyboard on a quick tap; ignores drags and long presses.
class _ShortTapKeyboardDismiss extends StatefulWidget {
  const _ShortTapKeyboardDismiss({
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_ShortTapKeyboardDismiss> createState() =>
      _ShortTapKeyboardDismissState();
}

class _ShortTapKeyboardDismissState extends State<_ShortTapKeyboardDismiss> {
  static const _maxTapDuration = Duration(milliseconds: 220);
  static const _maxMovement = 12.0;

  DateTime? _downAt;
  Offset? _downGlobal;
  bool _movedTooMuch = false;

  void _reset() {
    _downAt = null;
    _downGlobal = null;
    _movedTooMuch = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _downAt = DateTime.now();
        _downGlobal = e.position;
        _movedTooMuch = false;
      },
      onPointerMove: (e) {
        final start = _downGlobal;
        if (start == null || _movedTooMuch) return;
        if ((e.position - start).distance > _maxMovement) {
          _movedTooMuch = true;
        }
      },
      onPointerUp: (e) {
        final downAt = _downAt;
        final downGlobal = _downGlobal;
        final moved = _movedTooMuch;
        _reset();
        if (downAt == null || downGlobal == null || moved) return;
        if (DateTime.now().difference(downAt) > _maxTapDuration) return;
        if ((e.position - downGlobal).distance > _maxMovement) return;
        widget.onDismiss();
      },
      onPointerCancel: (_) => _reset(),
      child: widget.child,
    );
  }
}

class _ParticipantCell extends StatelessWidget {
  const _ParticipantCell({
    required this.icon,
    required this.label,
    required this.name,
    required this.isMe,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String name;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      isMe ? '$name (you)' : name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
