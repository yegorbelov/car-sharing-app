import 'vehicle.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.memberSince,
    required this.isHost,
    required this.isRenter,
    required this.rating,
    required this.reviewCount,
    required this.listings,
  });

  final int id;
  final String fullName;
  final String avatarUrl;
  final String memberSince;
  final bool isHost;
  final bool isRenter;
  final double rating;
  final int reviewCount;
  final List<Vehicle> listings;

  bool get hasRating => reviewCount > 0 && rating > 0;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  DateTime? get memberSinceDate {
    if (memberSince.isEmpty) return null;
    try {
      return DateTime.parse(memberSince.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  String get memberSinceLabel {
    final d = memberSinceDate;
    if (d == null) return 'Member';
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
    return 'Member since ${months[d.month - 1]} ${d.year}';
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final rawListings = j['listings'];
    final listings = rawListings is List
        ? rawListings
            .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
            .toList()
        : <Vehicle>[];

    return UserProfile(
      id: (j['id'] as num).toInt(),
      fullName: (j['fullName'] as String?)?.trim() ?? '',
      avatarUrl: (j['avatarUrl'] as String?) ?? '',
      memberSince: (j['memberSince'] as String?) ?? '',
      isHost: j['isHost'] as bool? ?? false,
      isRenter: j['isRenter'] as bool? ?? false,
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      listings: listings,
    );
  }
}
