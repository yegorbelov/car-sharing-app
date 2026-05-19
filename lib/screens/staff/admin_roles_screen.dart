import 'package:flutter/material.dart';

import '../../services/staff_api.dart';
import '../../widgets/app_snackbar.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  List<StaffUser> _users = [];
  List<AuditLogEntry> _audit = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await StaffApi.fetchUsers();
      final audit = await StaffApi.fetchAuditLog();
      if (!mounted) return;
      setState(() {
        _users = users;
        _audit = audit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.showAppSnackBar('$e');
    }
  }

  Future<void> _toggleRole(
    StaffUser u, {
    bool? admin,
    bool? moderator,
    bool? arbitrator,
  }) async {
    try {
      await StaffApi.updateUserRoles(
        userId: u.id,
        isAdmin: admin,
        isModerator: moderator,
        isArbitrator: arbitrator,
      );
      if (!mounted) return;
      context.showAppSnackBar('Roles updated.', kind: AppSnackBarKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('Platform admin'),
          backgroundColor: const Color(0xFFF4F6FA),
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'User roles'),
              Tab(text: 'Audit log'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  u.email,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Admin'),
                                  value: u.isAdmin,
                                  onChanged: (v) => _toggleRole(u, admin: v),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Listing moderator'),
                                  value: u.isModerator,
                                  onChanged: (v) => _toggleRole(u, moderator: v),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Dispute arbitrator'),
                                  value: u.isArbitrator,
                                  onChanged: (v) => _toggleRole(u, arbitrator: v),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _audit.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No staff actions yet.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _audit.length,
                            itemBuilder: (context, i) {
                              final e = _audit[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(e.action.replaceAll('_', ' ')),
                                  subtitle: Text(
                                    '${e.actorName} · ${e.entityType} #${e.entityId}\n${e.createdAt}',
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
