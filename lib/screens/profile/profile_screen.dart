import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../services/auth_api.dart';
import 'create_listing_screen.dart';

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
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Avatar card ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _uploadingAvatar
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : _buildAvatar(u, cs),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u?.fullName ?? 'Your profile',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u?.email ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Owner & Renter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Menu ───────────────────────────────────────────────────────
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
                  onTap: () {},
                ),
                const Divider(),
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  iconColor: cs.secondary,
                  title: 'Security',
                  onTap: () {},
                ),
                const Divider(),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  iconColor: cs.onSurfaceVariant,
                  title: 'Help & Support',
                  onTap: () {},
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
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        u?.initials ?? '—',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: cs.onPrimaryContainer,
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
