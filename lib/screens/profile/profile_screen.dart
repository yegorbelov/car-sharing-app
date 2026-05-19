import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../services/auth_api.dart';
import 'create_listing_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser? _user;
  bool _uploadingAvatar = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh profile: $e')),
      );
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await AuthApi.uploadAvatar(picked.path);
      if (!mounted) return;
      final updated = _user?.copyWith(avatarUrl: url);
      if (updated != null) {
        final token = await AuthStorage.getToken();
        if (token != null) await AuthStorage.saveSession(accessToken: token, user: updated);
        if (!mounted) return;
        setState(() => _user = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              children: [
                Card(
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: cs.primary,
                        title: 'Create listing',
                        subtitle: 'Add your car to the catalog',
                        onTap: () async {
                          final created = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const CreateListingScreen()),
                          );
                          if (!context.mounted) return;
                          if (created == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Listing published! Check the Catalog.')),
                            );
                          }
                        },
                      ),
                      const Divider(),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        iconColor: cs.tertiary,
                        title: 'Notifications',
                        onTap: () => _comingSoon('Notifications'),
                      ),
                      const Divider(),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        iconColor: cs.secondary,
                        title: 'Security',
                        onTap: () => _comingSoon('Security'),
                      ),
                      const Divider(),
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        iconColor: cs.onSurfaceVariant,
                        title: 'Help & Support',
                        onTap: () => _comingSoon('Help & Support'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: cs.errorContainer,
                    foregroundColor: cs.onErrorContainer,
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
        fit: BoxFit.cover,
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -50, right: -30, child: _glowOrb(160, 0.14)),
          Positioned(top: 70, left: -55, child: _glowOrb(120, 0.1)),
          Positioned(bottom: 10, right: 20, child: _glowOrb(90, 0.12)),
          Positioned(
            top: topPad + 12,
            right: 24,
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onPickAvatar,
                  child: Stack(
                    alignment: Alignment.center,
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
                          child: uploadingAvatar
                              ? ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.12),
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
                      Positioned(
                        bottom: 2,
                        right: 2,
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
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Your profile',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    label: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (iconColor ?? cs.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? cs.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
          : null,
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
      onTap: onTap,
    );
  }
}
