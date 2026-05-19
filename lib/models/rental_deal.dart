class RentalDeal {
  const RentalDeal({
    required this.id,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.renterId,
    required this.ownerId,
    required this.renterName,
    required this.ownerName,
    required this.status,
    required this.holdAmountCents,
    required this.myRole,
    required this.dayCount,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  final int id;
  final int vehicleId;
  final String vehicleTitle;
  final int renterId;
  final int ownerId;
  final String renterName;
  final String ownerName;
  final String status;
  final int holdAmountCents;
  final String myRole;
  final int dayCount;
  final String startDate;
  final String endDate;
  final String createdAt;

  bool get isRenter => myRole == 'renter';
  bool get isOwner => myRole == 'owner';

  factory RentalDeal.fromJson(Map<String, dynamic> j) {
    return RentalDeal(
      id: (j['id'] as num).toInt(),
      vehicleId: (j['vehicleId'] as num).toInt(),
      vehicleTitle: j['vehicleTitle'] as String,
      renterId: (j['renterId'] as num).toInt(),
      ownerId: (j['ownerId'] as num).toInt(),
      renterName: j['renterName'] as String,
      ownerName: j['ownerName'] as String,
      status: j['status'] as String,
      holdAmountCents: (j['holdAmountCents'] as num).toInt(),
      myRole: j['myRole'] as String,
      dayCount: (j['dayCount'] as num).toInt(),
      startDate: j['startDate'] as String,
      endDate: j['endDate'] as String,
      createdAt: j['createdAt'] as String,
    );
  }
}

class DealMessageReply {
  const DealMessageReply({
    required this.id,
    required this.senderId,
    required this.body,
    this.attachmentType,
  });

  final int id;
  final int senderId;
  final String body;
  final String? attachmentType;

  factory DealMessageReply.fromJson(Map<String, dynamic> j) {
    return DealMessageReply(
      id: (j['id'] as num).toInt(),
      senderId: (j['senderId'] as num).toInt(),
      body: j['body'] as String? ?? '',
      attachmentType: j['attachmentType'] as String?,
    );
  }
}

class DealMessage {
  const DealMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.replyToId,
    this.replyTo,
  });

  final int id;
  final int senderId;
  final String body;
  final String createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final int? replyToId;
  final DealMessageReply? replyTo;

  bool get hasAttachment => (attachmentUrl ?? '').isNotEmpty;

  bool get isImageAttachment => attachmentType == 'image';

  bool get isFileAttachment => attachmentType == 'file';

  factory DealMessage.fromJson(Map<String, dynamic> j) {
    final rawReply = j['replyTo'];
    return DealMessage(
      id: (j['id'] as num).toInt(),
      senderId: (j['senderId'] as num).toInt(),
      body: j['body'] as String? ?? '',
      createdAt: j['createdAt'] as String,
      attachmentUrl: j['attachmentUrl'] as String?,
      attachmentType: j['attachmentType'] as String?,
      attachmentName: j['attachmentName'] as String?,
      replyToId: (j['replyToId'] as num?)?.toInt(),
      replyTo: rawReply is Map<String, dynamic>
          ? DealMessageReply.fromJson(rawReply)
          : null,
    );
  }
}

class WalletData {
  const WalletData({
    required this.balanceCents,
    required this.balance,
    required this.recent,
  });

  final int balanceCents;
  final double balance;
  final List<LedgerEntry> recent;

  factory WalletData.fromJson(Map<String, dynamic> j) {
    final raw = j['recent'] as List<dynamic>? ?? [];
    return WalletData(
      balanceCents: (j['balanceCents'] as num).toInt(),
      balance: (j['balance'] as num).toDouble(),
      recent: raw.map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.deltaCents,
    required this.entryType,
    required this.note,
    required this.createdAt,
    this.dealId,
    this.vehicleTitle,
    this.dealStatus,
  });

  final int id;
  final int deltaCents;
  final String entryType;
  final String note;
  final String createdAt;
  final int? dealId;
  final String? vehicleTitle;
  final String? dealStatus;

  bool get hasDeal => dealId != null;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    return LedgerEntry(
      id: (j['id'] as num).toInt(),
      deltaCents: (j['deltaCents'] as num).toInt(),
      entryType: j['entryType'] as String,
      note: j['note'] as String,
      createdAt: j['createdAt'] as String,
      dealId: (j['dealId'] as num?)?.toInt(),
      vehicleTitle: j['vehicleTitle'] as String?,
      dealStatus: j['dealStatus'] as String?,
    );
  }
}
