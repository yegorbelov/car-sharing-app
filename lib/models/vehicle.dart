class Vehicle {
  const Vehicle({
    required this.id,
    required this.title,
    required this.city,
    required this.className,
    required this.pricePerDayCents,
    required this.rating,
    this.reviewCount = 0,
    this.createdAt = '',
    this.ownerUserId,
    this.photoUrl = '',
    this.photoUrls = const [],
    this.mileageKm = 0,
    this.modelYear = 0,
    this.transmission = '',
    this.fuelType = '',
    this.drivetrain = '',
    this.engineCc = 0,
    this.exteriorColor = '',
    this.conditionSummary = '',
    this.techNotes = '',
    this.vin = '',
    this.listingStatus = 'published',
    this.latitude,
    this.longitude,
    this.completedTrips = 0,
    this.minRentalDays = 1,
    this.maxRentalDays = 14,
    this.seatCount = 5,
    this.petsAllowed = false,
    this.fuelReturnPolicy = 'same_level',
    this.moderationNote = '',
  });

  final int id;
  final String title;
  final String city;
  final String className;
  final int pricePerDayCents;
  final double rating;
  final int reviewCount;
  final String createdAt;
  final int? ownerUserId;

  /// Primary cover URL (first gallery image when present).
  final String photoUrl;
  final List<String> photoUrls;
  final int mileageKm;
  final int modelYear;
  final String transmission;
  final String fuelType;
  final String drivetrain;
  final int engineCc;
  final String exteriorColor;
  final String conditionSummary;
  final String techNotes;
  final String vin;
  final String listingStatus;
  final double? latitude;
  final double? longitude;
  final int completedTrips;
  final int minRentalDays;
  final int maxRentalDays;
  final int seatCount;
  final bool petsAllowed;
  final String fuelReturnPolicy;
  final String moderationNote;

  double get pricePerDay => pricePerDayCents / 100;

  int get effectiveMinRentalDays => minRentalDays > 0 ? minRentalDays : 1;

  int get effectiveMaxRentalDays =>
      maxRentalDays >= effectiveMinRentalDays ? maxRentalDays : effectiveMinRentalDays;

  String get rentalDaysRangeLabel {
    final min = effectiveMinRentalDays;
    final max = effectiveMaxRentalDays;
    if (min == max) return min == 1 ? '1 day min/max' : '$min days only';
    return '$min–$max days';
  }

  String get seatsLabel =>
      seatCount == 1 ? '1 seat' : '$seatCount seats';

  String get petsPolicyLabel => petsAllowed ? 'Pets allowed' : 'No pets';

  String get fuelReturnPolicyLabel => switch (fuelReturnPolicy) {
    'full_tank' => 'Return with full tank',
    'quarter_tank' => 'Return with at least ¼ tank',
    'same_level' || _ => 'Return with same fuel level',
  };

  bool get isPublished => listingStatus == 'published';

  bool get isPendingModeration => listingStatus == 'pending_moderation';

  bool get isUnpublished => listingStatus == 'unpublished';

  bool get isRejected => listingStatus == 'rejected';

  bool get canUnpublish => isPublished || isPendingModeration;

  bool get hasModerationNote => moderationNote.trim().isNotEmpty;

  bool get canRepublish => isUnpublished;

  String get listingStatusLabel => switch (listingStatus) {
    'published' => 'Published',
    'pending_moderation' => 'Under review',
    'unpublished' => 'Unpublished',
    'rejected' => 'Rejected',
    _ => listingStatus,
  };

  String get completedTripsLabel =>
      completedTrips == 1 ? '1 successful trip' : '$completedTrips successful trips';

  DateTime? get createdAtDate {
    if (createdAt.isEmpty) return null;
    try {
      return DateTime.parse(createdAt.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  String get subtitle => '$city · ${_classLabel(className)}';

  /// City and model year for catalog cards (year omitted if unknown).
  String get catalogLocationLabel =>
      modelYear > 0 ? '$city · $modelYear' : city;

  String get reviewCountLabel =>
      reviewCount == 1 ? '1 review' : '$reviewCount reviews';

  /// URLs for gallery (non-empty); falls back to single cover.
  List<String> get galleryUrls {
    if (photoUrls.isNotEmpty) return photoUrls;
    if (photoUrl.isNotEmpty) return [photoUrl];
    return const [];
  }

  String _classLabel(String c) => switch (c.toLowerCase()) {
    'sedan' => 'Sedan',
    'suv' => 'SUV',
    'economy' => 'Economy',
    'comfort' => 'Comfort',
    'business' => 'Business',
    _ => c,
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photoUrls'];
    var urls = <String>[];
    if (rawPhotos is List) {
      urls = rawPhotos
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    var cover = (j['photoUrl'] as String?) ?? '';
    if (cover.isEmpty && urls.isNotEmpty) {
      cover = urls.first;
    }

    return Vehicle(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String,
      city: j['city'] as String,
      className: j['class'] as String,
      pricePerDayCents: (j['pricePerDayCents'] as num).toInt(),
      rating: (j['rating'] as num).toDouble(),
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: (j['createdAt'] as String?) ?? '',
      ownerUserId: (j['ownerUserId'] as num?)?.toInt(),
      photoUrl: cover,
      photoUrls: urls,
      mileageKm: (j['mileageKm'] as num?)?.toInt() ?? 0,
      modelYear: (j['modelYear'] as num?)?.toInt() ?? 0,
      transmission: (j['transmission'] as String?) ?? '',
      fuelType: (j['fuelType'] as String?) ?? '',
      drivetrain: (j['drivetrain'] as String?) ?? '',
      engineCc: (j['engineCc'] as num?)?.toInt() ?? 0,
      exteriorColor: (j['exteriorColor'] as String?) ?? '',
      conditionSummary: (j['conditionSummary'] as String?) ?? '',
      techNotes: (j['techNotes'] as String?) ?? '',
      vin: (j['vin'] as String?) ?? '',
      listingStatus: (j['listingStatus'] as String?) ?? 'published',
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      completedTrips: (j['completedTrips'] as num?)?.toInt() ?? 0,
      minRentalDays: (j['minRentalDays'] as num?)?.toInt() ?? 1,
      maxRentalDays: (j['maxRentalDays'] as num?)?.toInt() ?? 14,
      seatCount: (j['seatCount'] as num?)?.toInt() ?? 5,
      petsAllowed: j['petsAllowed'] as bool? ?? false,
      fuelReturnPolicy:
          (j['fuelReturnPolicy'] as String?)?.trim() ?? 'same_level',
      moderationNote: (j['moderationNote'] as String?) ?? '',
    );
  }

  Vehicle copyWith({
    int? id,
    String? title,
    String? city,
    String? className,
    int? pricePerDayCents,
    double? rating,
    int? reviewCount,
    String? createdAt,
    int? ownerUserId,
    String? photoUrl,
    List<String>? photoUrls,
    int? mileageKm,
    int? modelYear,
    String? transmission,
    String? fuelType,
    String? drivetrain,
    int? engineCc,
    String? exteriorColor,
    String? conditionSummary,
    String? techNotes,
    String? vin,
    String? listingStatus,
    double? latitude,
    double? longitude,
    int? completedTrips,
    int? minRentalDays,
    int? maxRentalDays,
    int? seatCount,
    bool? petsAllowed,
    String? fuelReturnPolicy,
    String? moderationNote,
  }) {
    return Vehicle(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      className: className ?? this.className,
      pricePerDayCents: pricePerDayCents ?? this.pricePerDayCents,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      mileageKm: mileageKm ?? this.mileageKm,
      modelYear: modelYear ?? this.modelYear,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      drivetrain: drivetrain ?? this.drivetrain,
      engineCc: engineCc ?? this.engineCc,
      exteriorColor: exteriorColor ?? this.exteriorColor,
      conditionSummary: conditionSummary ?? this.conditionSummary,
      techNotes: techNotes ?? this.techNotes,
      vin: vin ?? this.vin,
      listingStatus: listingStatus ?? this.listingStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      completedTrips: completedTrips ?? this.completedTrips,
      minRentalDays: minRentalDays ?? this.minRentalDays,
      maxRentalDays: maxRentalDays ?? this.maxRentalDays,
      seatCount: seatCount ?? this.seatCount,
      petsAllowed: petsAllowed ?? this.petsAllowed,
      fuelReturnPolicy: fuelReturnPolicy ?? this.fuelReturnPolicy,
      moderationNote: moderationNote ?? this.moderationNote,
    );
  }
}
