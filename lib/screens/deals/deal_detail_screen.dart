import 'package:flutter/material.dart';

import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../models/rental_deal.dart';
import '../../services/deals_api.dart';
import '../../widgets/app_input.dart';

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

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
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
      _scrollBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _reloadMessages() async {
    try {
      final m = await DealsApi.fetchMessages(widget.dealId);
      if (!mounted) return;
      setState(() => _messages = m);
      _scrollBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    try {
      await DealsApi.postMessage(widget.dealId, text);
      await _reloadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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

          const Divider(height: 1),

          // Chat
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = me?.id == m.senderId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          decoration: BoxDecoration(
                            color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                _fmtTime(m.createdAt),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          SafeArea(
            top: false,
            child: Material(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: AppInputs.chat(context),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded),
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
