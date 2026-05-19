import 'package:flutter/material.dart';

import '../../core/auth_storage.dart';
import '../../services/auth_api.dart';
import '../../widgets/app_input.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid_credentials':
        return 'Wrong email or password.';
      case 'invalid_email':
        return 'Enter a valid email.';
      case 'weak_password':
        return 'Password must be at least 8 characters and include letters and numbers.';
      case 'email_taken':
        return 'This email is already registered.';
      case 'invalid_json':
        return 'Invalid request.';
      default:
        return code;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final r = await AuthApi.login(
        email: _email.text,
        password: _password.text,
      );
      await AuthStorage.saveSession(accessToken: r.token, user: r.user);
      if (!mounted) return;
      widget.onSignedIn();
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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.85),
              cs.surface,
              cs.secondaryContainer.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.directions_car_rounded, size: 56, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Car Sharing',
                      textAlign: TextAlign.center,
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Peer-to-peer rentals',
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Sign in', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
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
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
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
                                  return null;
                                },
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(color: cs.error, fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('New here?', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () async {
                                            final ok = await Navigator.of(context).push<bool>(
                                              MaterialPageRoute(
                                                builder: (_) => const RegisterScreen(),
                                              ),
                                            );
                                            if (ok == true && mounted) {
                                              widget.onSignedIn();
                                            }
                                          },
                                    child: const Text('Create account'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
