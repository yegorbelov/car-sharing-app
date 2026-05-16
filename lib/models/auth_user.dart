class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
  });

  final int id;
  final String email;
  final String fullName;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    return AuthUser(
      id: (j['id'] as num).toInt(),
      email: j['email'] as String,
      fullName: (j['fullName'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
      };
}
