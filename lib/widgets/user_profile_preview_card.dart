import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/api_config.dart';
import '../models/user_profile.dart';
import '../screens/profile/user_profile_screen.dart';
import '../services/users_api.dart';

/// Compact tappable row that loads a public user profile.
class UserProfilePreviewCard extends StatefulWidget {
  const UserProfilePreviewCard({
    super.key,
    required this.userId,
    required this.roleLabel,
    required this.icon,
    this.fallbackName,
  });

  final int userId;
  final String roleLabel;
  final IconData icon;
  final String? fallbackName;

  @override
  State<UserProfilePreviewCard> createState() => _UserProfilePreviewCardState();
}

class _UserProfilePreviewCardState extends State<UserProfilePreviewCard> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await UsersApi.fetchProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _profile;
    final name = p?.fullName ?? widget.fallbackName ?? 'View profile';
    final avatarUrl =
        p != null && p.avatarUrl.isNotEmpty ? fullImageUrl(p.avatarUrl) : null;

    return Material(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (_loading)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary.withValues(alpha: 0.5),
                  ),
                )
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          p?.initials ??
                              (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roleLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (p != null) ...[
                      const SizedBox(height: 4),
                      if (p.hasRating)
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/star.svg',
                              width: 14,
                              height: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.rating.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.reviewCount == 1
                                  ? '1 review'
                                  : '${p.reviewCount} reviews',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          p.memberSinceLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
