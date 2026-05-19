class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl = '',
    this.isAdmin = false,
    this.isModerator = false,
    this.isArbitrator = false,
    this.roles = const [],
  });

  final int id;
  final String email;
  final String fullName;
  final String avatarUrl;
  final bool isAdmin;
  final bool isModerator;
  final bool isArbitrator;
  final List<String> roles;

  bool get canModerateListings => isAdmin || isModerator;
  bool get canArbitrateDisputes => isAdmin || isArbitrator;
  bool get canManagePlatform => isAdmin;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty);
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

  String get staffRolesLabel {
    final labels = <String>[];
    if (isAdmin) labels.add('Admin');
    if (isModerator) labels.add('Moderator');
    if (isArbitrator) labels.add('Arbitrator');
    return labels.join(' · ');
  }

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    final rawRoles = j['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : <String>[];
    return AuthUser(
      id: (j['id'] as num).toInt(),
      email: j['email'] as String,
      fullName: (j['fullName'] as String?)?.trim() ?? '',
      avatarUrl: (j['avatarUrl'] as String?) ?? '',
      isAdmin: j['isAdmin'] as bool? ?? false,
      isModerator: j['isModerator'] as bool? ?? false,
      isArbitrator: j['isArbitrator'] as bool? ?? false,
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'avatarUrl': avatarUrl,
    'isAdmin': isAdmin,
    'isModerator': isModerator,
    'isArbitrator': isArbitrator,
    'roles': roles,
  };

  AuthUser copyWith({
    String? fullName,
    String? avatarUrl,
    bool? isAdmin,
    bool? isModerator,
    bool? isArbitrator,
    List<String>? roles,
  }) {
    return AuthUser(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
      isArbitrator: isArbitrator ?? this.isArbitrator,
      roles: roles ?? this.roles,
    );
  }
}
