class VehicleReview {
  const VehicleReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String authorName;
  final double rating;
  final String body;
  final String createdAt;

  factory VehicleReview.fromJson(Map<String, dynamic> j) {
    return VehicleReview(
      id: (j['id'] as num).toInt(),
      authorName: j['authorName'] as String,
      rating: (j['rating'] as num).toDouble(),
      body: j['body'] as String? ?? '',
      createdAt: j['createdAt'] as String? ?? '',
    );
  }
}
