class Vehicle {
  const Vehicle({
    required this.id,
    required this.title,
    required this.city,
    required this.className,
    required this.pricePerDayCents,
    required this.rating,
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
  });

  final int id;
  final String title;
  final String city;
  final String className;
  final int pricePerDayCents;
  final double rating;
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

  double get pricePerDay => pricePerDayCents / 100;

  String get subtitle => '$city · ${_classLabel(className)}';

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
      urls = rawPhotos.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
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
    );
  }

  Vehicle copyWith({
    int? id,
    String? title,
    String? city,
    String? className,
    int? pricePerDayCents,
    double? rating,
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
  }) {
    return Vehicle(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      className: className ?? this.className,
      pricePerDayCents: pricePerDayCents ?? this.pricePerDayCents,
      rating: rating ?? this.rating,
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
    );
  }
}
