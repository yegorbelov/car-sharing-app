import 'package:flutter/material.dart';

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
    } catch (_) {
      /* keep cached user */
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    child: Text(
                      u?.initials ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u?.fullName ?? 'Signed in',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Owner & renter',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: cs.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Create listing'),
                  subtitle: const Text('Add a car to the catalog'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
                    );
                    if (!context.mounted) return;
                    if (created == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Listing published. Open Catalog to see it.')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Security'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
