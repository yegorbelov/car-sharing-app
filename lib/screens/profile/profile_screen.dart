import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../services/auth_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser? _user;
  String? _healthBody;
  String? _healthError;
  bool _healthLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadHealth();
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

  Future<void> _loadHealth() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
      _healthBody = null;
    });
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/health');
    try {
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _healthBody = response.body;
          _healthLoading = false;
        });
      } else {
        setState(() {
          _healthError = 'HTTP ${response.statusCode}: ${response.body}';
          _healthLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthError = e.toString();
        _healthLoading = false;
      });
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
          const SizedBox(height: 28),
          Text(
            'API health',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${apiBaseUrl()}/api/v1/health',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        onPressed: _healthLoading ? null : _loadHealth,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_healthLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_healthError != null)
                    SelectableText(
                      _healthError!,
                      style: TextStyle(color: cs.error),
                    )
                  else
                    SelectableText(
                      _healthBody ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
