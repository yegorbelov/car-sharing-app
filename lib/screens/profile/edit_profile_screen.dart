import 'package:flutter/material.dart';

import '../../core/auth_storage.dart';
import '../../models/auth_user.dart';
import '../../services/auth_api.dart';
import '../../widgets/app_input.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.fullName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid_full_name':
        return 'Name must be 2–100 characters.';
      case 'invalid_json':
        return 'Invalid request.';
      case 'unauthorized':
      case 'session_invalid':
        return 'Session expired. Please sign in again.';
      default:
        return code;
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final updated = await AuthApi.updateProfile(fullName: _name.text);
      final token = await AuthStorage.getToken();
      if (token != null) {
        await AuthStorage.saveSession(accessToken: token, user: updated);
      }
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapError(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_error != null) ...[
            MaterialBanner(
              content: Text(_error!),
              backgroundColor: cs.errorContainer,
              leading: Icon(Icons.error_outline, color: cs.onErrorContainer),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: AppInputs.decoration(
                        context,
                        labelText: 'Full name',
                        hintText: 'How others see you',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 2) return 'At least 2 characters';
                        if (t.length > 100) return 'Max 100 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.user.email,
                      readOnly: true,
                      decoration: AppInputs.decoration(
                        context,
                        labelText: 'Email',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email cannot be changed here.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
