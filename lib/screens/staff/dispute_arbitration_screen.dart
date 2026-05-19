import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_config.dart';
import '../../models/dispute.dart';
import '../../services/staff_api.dart';
import '../../widgets/app_snackbar.dart';

class DisputeArbitrationScreen extends StatefulWidget {
  const DisputeArbitrationScreen({super.key});

  @override
  State<DisputeArbitrationScreen> createState() =>
      _DisputeArbitrationScreenState();
}

class _DisputeArbitrationScreenState extends State<DisputeArbitrationScreen> {
  List<RentalDispute> _queue = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final queue = await StaffApi.fetchArbitrationQueue();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Future<void> _resolve(RentalDispute d) async {
    var resolution = 'favor_renter';
    final renterCtrl = TextEditingController(
      text: '${d.holdAmountCents}',
    );
    final ownerCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final hold = d.holdAmountCents;
          return AlertDialog(
            title: const Text('Resolve dispute'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    d.vehicleTitle,
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  Text(
                    '${d.renterName} vs ${d.ownerName} · Hold ${_money(hold)}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d.reasonLabel,
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(d.description),
                  const SizedBox(height: 12),
                  ...[
                    ('favor_renter', 'Full refund to renter'),
                    ('favor_owner', 'Full payout to owner'),
                    ('split', 'Custom split'),
                  ].map(
                    (opt) => RadioListTile<String>(
                      title: Text(opt.$2),
                      value: opt.$1,
                      groupValue: resolution,
                      onChanged: (val) {
                        setDlg(() {
                          resolution = val ?? resolution;
                          if (resolution == 'favor_renter') {
                            renterCtrl.text = '$hold';
                            ownerCtrl.text = '0';
                          } else if (resolution == 'favor_owner') {
                            renterCtrl.text = '0';
                            ownerCtrl.text = '$hold';
                          }
                        });
                      },
                    ),
                  ),
                  if (resolution == 'split') ...[
                    TextField(
                      controller: renterCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Renter refund (cents)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ownerCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Owner payout (cents)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note for audit (optional)',
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
                child: const Text('Resolve'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      renterCtrl.dispose();
      ownerCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    int? renterRefund;
    int? ownerPayout;
    if (resolution == 'split') {
      renterRefund = int.tryParse(renterCtrl.text.trim());
      ownerPayout = int.tryParse(ownerCtrl.text.trim());
    }
    final note = noteCtrl.text.trim();
    renterCtrl.dispose();
    ownerCtrl.dispose();
    noteCtrl.dispose();

    try {
      await StaffApi.resolveDispute(
        disputeId: d.id,
        resolution: resolution,
        renterRefundCents: renterRefund,
        ownerPayoutCents: ownerPayout,
        note: note,
      );
      if (!mounted) return;
      context.showAppSnackBar(
        'Dispute resolved.',
        kind: AppSnackBarKind.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar('$e');
    }
  }

  void _showDetails(RentalDispute d) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(
            controller: scroll,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                d.vehicleTitle,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('Deal #${d.dealId} · ${d.reasonLabel}'),
              const SizedBox(height: 12),
              Text(d.description),
              const SizedBox(height: 8),
              Text(
                'Opened by ${d.openedByName}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (d.evidence.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Evidence',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...d.evidence.map((e) {
                  final url = fullImageUrl(e.attachmentUrl);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (url.isNotEmpty && e.attachmentType == 'image')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (e.caption.isNotEmpty) Text(e.caption),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resolve(d);
                },
                child: const Text('Resolve dispute'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Dispute arbitration'),
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : _queue.isEmpty
          ? const Center(child: Text('No open disputes in the queue.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _queue.length,
                itemBuilder: (context, i) {
                  final d = _queue[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showDetails(d),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.gavel_rounded,
                                  color: cs.tertiary,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    d.vehicleTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  _money(d.holdAmountCents),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.reasonLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d.renterName} · ${d.ownerName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonal(
                                onPressed: () => _resolve(d),
                                child: const Text('Resolve'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
