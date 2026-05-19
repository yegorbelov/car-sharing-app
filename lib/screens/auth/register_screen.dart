import 'package:flutter/material.dart';

import '../../core/auth_storage.dart';
import '../../services/auth_api.dart';
import '../../widgets/app_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _mapError(String code) {
    switch (code) {
      case 'email_taken':
        return 'This email is already registered.';
      case 'invalid_email':
        return 'Enter a valid email.';
      case 'weak_password':
        return 'Use at least 8 characters with letters and numbers.';
      case 'invalid_json':
        return 'Invalid request.';
      default:
        return code;
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final r = await AuthApi.register(
        email: _email.text,
        password: _password.text,
        fullName: _name.text,
      );
      await AuthStorage.saveSession(accessToken: r.token, user: r.user);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  bool _strongPassword(String p) {
    if (p.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
    final hasDigit = RegExp(r'\d').hasMatch(p);
    return hasLetter && hasDigit;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join Car Sharing',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '8+ characters, letters and numbers.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppInputs.decoration(
                    context,
                    labelText: 'Full name',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: AppInputs.fieldGap),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: AppInputs.decoration(
                    context,
                    labelText: 'Email',
                    icon: Icons.mail_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppInputs.fieldGap),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: AppInputs.decoration(
                    context,
                    labelText: 'Password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!_strongPassword(v)) {
                      return '8+ chars with letters and numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppInputs.fieldGap),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: AppInputs.decoration(
                    context,
                    labelText: 'Confirm password',
                    icon: Icons.verified_user_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _password.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
