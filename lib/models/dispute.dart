class DisputeReason {
  const DisputeReason({required this.code, required this.label});

  final String code;
  final String label;

  factory DisputeReason.fromJson(Map<String, dynamic> j) => DisputeReason(
    code: j['code'] as String,
    label: j['label'] as String,
  );
}

class DisputeEvidence {
  const DisputeEvidence({
    required this.id,
    required this.attachmentUrl,
    required this.attachmentType,
    required this.caption,
    required this.uploadedBy,
    required this.createdAt,
  });

  final int id;
  final String attachmentUrl;
  final String attachmentType;
  final String caption;
  final int uploadedBy;
  final String createdAt;

  factory DisputeEvidence.fromJson(Map<String, dynamic> j) => DisputeEvidence(
    id: (j['id'] as num).toInt(),
    attachmentUrl: j['attachmentUrl'] as String? ?? '',
    attachmentType: j['attachmentType'] as String? ?? 'image',
    caption: j['caption'] as String? ?? '',
    uploadedBy: (j['uploadedBy'] as num).toInt(),
    createdAt: j['createdAt'] as String? ?? '',
  );
}

class RentalDispute {
  const RentalDispute({
    required this.id,
    required this.dealId,
    required this.status,
    required this.reasonCode,
    required this.reasonLabel,
    required this.description,
    required this.openedByUserId,
    required this.openedByName,
    required this.renterRefundCents,
    required this.ownerPayoutCents,
    required this.holdAmountCents,
    required this.dealStatus,
    required this.vehicleTitle,
    required this.renterName,
    required this.ownerName,
    required this.createdAt,
    required this.evidence,
    this.resolutionCode,
    this.resolutionNote,
    this.arbitratorUserId,
    this.arbitratorName,
    this.resolvedAt,
  });

  final int id;
  final int dealId;
  final String status;
  final String reasonCode;
  final String reasonLabel;
  final String description;
  final int openedByUserId;
  final String openedByName;
  final int renterRefundCents;
  final int ownerPayoutCents;
  final int holdAmountCents;
  final String dealStatus;
  final String vehicleTitle;
  final String renterName;
  final String ownerName;
  final String createdAt;
  final List<DisputeEvidence> evidence;
  final String? resolutionCode;
  final String? resolutionNote;
  final int? arbitratorUserId;
  final String? arbitratorName;
  final String? resolvedAt;

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';

  factory RentalDispute.fromJson(Map<String, dynamic> j) {
    final rawEv = j['evidence'] as List<dynamic>? ?? [];
    return RentalDispute(
      id: (j['id'] as num).toInt(),
      dealId: (j['dealId'] as num).toInt(),
      status: j['status'] as String,
      reasonCode: j['reasonCode'] as String,
      reasonLabel: j['reasonLabel'] as String? ?? j['reasonCode'] as String,
      description: j['description'] as String? ?? '',
      openedByUserId: (j['openedByUserId'] as num).toInt(),
      openedByName: j['openedByName'] as String? ?? '',
      renterRefundCents: (j['renterRefundCents'] as num?)?.toInt() ?? 0,
      ownerPayoutCents: (j['ownerPayoutCents'] as num?)?.toInt() ?? 0,
      holdAmountCents: (j['holdAmountCents'] as num).toInt(),
      dealStatus: j['dealStatus'] as String? ?? '',
      vehicleTitle: j['vehicleTitle'] as String? ?? '',
      renterName: j['renterName'] as String? ?? '',
      ownerName: j['ownerName'] as String? ?? '',
      createdAt: j['createdAt'] as String? ?? '',
      evidence: rawEv
          .map((e) => DisputeEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
      resolutionCode: j['resolutionCode'] as String?,
      resolutionNote: j['resolutionNote'] as String?,
      arbitratorUserId: (j['arbitratorUserId'] as num?)?.toInt(),
      arbitratorName: j['arbitratorName'] as String?,
      resolvedAt: j['resolvedAt'] as String?,
    );
  }
}
