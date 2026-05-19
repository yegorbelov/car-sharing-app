import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../services/auth_api.dart';
import '../../widgets/app_snackbar.dart';
import '../staff/admin_roles_screen.dart';
import '../staff/dispute_arbitration_screen.dart';
import '../staff/moderation_screen.dart';
import 'create_listing_screen.dart';
import 'edit_profile_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onSignedOut,
    this.onListingCreated,
  });

  final VoidCallback onSignedOut;
  final VoidCallback? onListingCreated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser? _user;
  bool _uploadingAvatar = false;

  static const _pageBg = Color(0xFFF4F6FA);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final cached = await AuthStorage.getUser();
    if (!mounted) return;
    setState(() => _user = cached);
    final token = await AuthStorage.getToken();
    if (token == null || !mounted) return;
    try {
      final fresh = await AuthApi.fetchMe(token);
      if (!mounted) return;
      await AuthStorage.saveSession(accessToken: token, user: fresh);
      setState(() => _user = fresh);
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar('Could not refresh profile: $e');
    }
  }

  void _comingSoon(String feature) {
    context.showAppSnackBar('$feature — coming soon');
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await AuthApi.uploadAvatar(picked.path);
      if (!mounted) return;
      final updated = _user?.copyWith(avatarUrl: url);
      if (updated != null) {
        final token = await AuthStorage.getToken();
        if (token != null) {
          await AuthStorage.saveSession(accessToken: token, user: updated);
        }
        if (!mounted) return;
        setState(() => _user = updated);
      }
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _signOut() async {
    await AuthStorage.clear();
    if (!mounted) return;
    widget.onSignedOut();
  }

  Future<void> _openEditProfile() async {
    final u = _user;
    if (u == null) return;
    final updated = await Navigator.of(context).push<AuthUser>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: u)),
    );
    if (!mounted || updated == null) return;
    setState(() => _user = updated);
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (!mounted) return;
    if (created == true) {
      widget.onListingCreated?.call();
      context.showAppSnackBar(
        'Listing submitted for review. We’ll notify you when it’s live.',
        kind: AppSnackBarKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = 56.0 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            user: u,
            uploadingAvatar: _uploadingAvatar,
            onPickAvatar: _pickAvatar,
            onEdit: u != null ? _openEditProfile : null,
            avatarBuilder: () => _buildAvatar(u, cs),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileMenuGroup(
                  title: 'Hosting',
                  children: [
                    _ProfileMenuTile(
                      icon: Icons.add_circle_outline_rounded,
                      iconBg: cs.primaryContainer,
                      iconColor: cs.primary,
                      title: 'Create listing',
                      subtitle: 'Add your car to the catalog',
                      onTap: _openCreateListing,
                      showDivider: false,
                    ),
                  ],
                ),
                if (u != null &&
                    (u.canModerateListings ||
                        u.canArbitrateDisputes ||
                        u.canManagePlatform)) ...[
                  const SizedBox(height: 14),
                  _ProfileMenuGroup(
                    title: 'Platform',
                    children: [
                      if (u.canModerateListings)
                        _ProfileMenuTile(
                          icon: Icons.fact_check_outlined,
                          iconBg: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF2E7D32),
                          title: 'Listing moderation',
                          subtitle: 'Approve or reject new listings',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ModerationScreen(),
                              ),
                            );
                          },
                        ),
                      if (u.canManagePlatform)
                        _ProfileMenuTile(
                          icon: Icons.admin_panel_settings_outlined,
                          iconBg: const Color(0xFFE3F2FD),
                          iconColor: const Color(0xFF1565C0),
                          title: 'User roles & audit',
                          subtitle: 'Assign moderators and arbitrators',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminRolesScreen(),
                              ),
                            );
                          },
                        ),
                      if (u.canArbitrateDisputes)
                        _ProfileMenuTile(
                          icon: Icons.gavel_outlined,
                          iconBg: const Color(0xFFFFF3E0),
                          iconColor: const Color(0xFFE65100),
                          title: 'Dispute arbitration',
                          subtitle: 'Resolve renter–owner conflicts',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DisputeArbitrationScreen(),
                              ),
                            );
                          },
                          showDivider: false,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _ProfileMenuGroup(
                  title: 'Account',
                  children: [
                    if (u != null)
                      _ProfileMenuTile(
                        icon: Icons.verified_user_outlined,
                        iconBg: const Color(0xFFE8F5E9),
                        iconColor: const Color(0xFF2E7D32),
                        title: 'Public profile',
                        subtitle: 'How hosts and renters see you',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: u.id),
                            ),
                          );
                        },
                      ),
                    _ProfileMenuTile(
                      icon: Icons.notifications_outlined,
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFE65100),
                      title: 'Notifications',
                      onTap: () => _comingSoon('Notifications'),
                    ),
                    _ProfileMenuTile(
                      icon: Icons.lock_outline_rounded,
                      iconBg: const Color(0xFFE8EAF6),
                      iconColor: const Color(0xFF3949AB),
                      title: 'Security',
                      onTap: () => _comingSoon('Security'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileMenuGroup(
                  title: 'Support',
                  children: [
                    _ProfileMenuTile(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFE3F2FD),
                      iconColor: const Color(0xFF1565C0),
                      title: 'Help & Support',
                      onTap: () => _comingSoon('Help & Support'),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _signOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: cs.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sign out',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AuthUser? u, ColorScheme cs) {
    final url = u?.avatarUrl ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        fullImageUrl(url),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stack) => _initialsWidget(u, cs),
      );
    }
    return _initialsWidget(u, cs);
  }

  Widget _initialsWidget(AuthUser? u, ColorScheme cs) {
    return Container(
      color: const Color(0xFF3D3D52),
      alignment: Alignment.center,
      child: Text(
        u?.initials ?? '—',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.avatarBuilder,
    this.onEdit,
  });

  final AuthUser? user;
  final bool uploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback? onEdit;
  final Widget Function() avatarBuilder;

  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0A0F),
      Color(0xFF151522),
      Color(0xFF252538),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: _headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -50, right: -30, child: _glowOrb(160, 0.14)),
          Positioned(top: 70, left: -55, child: _glowOrb(120, 0.1)),
          Positioned(bottom: 10, right: 20, child: _glowOrb(90, 0.12)),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: onPickAvatar,
                    child: SizedBox(
                      width: 108,
                      height: 108,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                                width: 3.5,
                              ),
                            ),
                            child: ClipOval(
                              child: SizedBox.expand(
                                child: uploadingAvatar
                                    ? ColoredBox(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : avatarBuilder(),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF252538),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Your profile',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (user != null && user!.staffRolesLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    user!.staffRolesLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (onEdit != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    label: Text(
                      'Edit profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    'Owner & Renter',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: 14,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
