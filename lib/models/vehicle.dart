class Vehicle {
  const Vehicle({
    required this.id,
    required this.title,
    required this.city,
    required this.className,
    required this.pricePerDayCents,
    required this.rating,
    this.ownerUserId,
  });

  final int id;
  final String title;
  final String city;
  final String className;
  final int pricePerDayCents;
  final double rating;
  final int? ownerUserId;

  double get pricePerDay => pricePerDayCents / 100;

  String get subtitle => '$city · $className';

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    return Vehicle(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String,
      city: j['city'] as String,
      className: j['class'] as String,
      pricePerDayCents: (j['pricePerDayCents'] as num).toInt(),
      rating: (j['rating'] as num).toDouble(),
      ownerUserId: (j['ownerUserId'] as num?)?.toInt(),
    );
  }
}
