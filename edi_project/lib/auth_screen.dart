import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'candidate');
  final _passwordController = TextEditingController(text: 'student123');
  final _sideCameraController = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;
  bool _obscure = true;
  String _role = 'student';
  String? _error;
  bool _prefilledSideCamera = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilledSideCamera) {
      _sideCameraController.text = context.read<AppState>().sideCameraUrl;
      _prefilledSideCamera = true;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AppState>().login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role,
        rememberMe: _rememberMe,
        sideCameraUrl: _role == 'student'
            ? _sideCameraController.text.trim()
            : '',
      );
      if (!mounted) return;
      final state = context.read<AppState>();
      Navigator.pushReplacementNamed(
        context,
        state.isTeacher
            ? '/teacher_home'
            : state.isProctor
            ? '/admin_home'
            : '/student_home',
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08111F), Color(0xFF0B1020), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.security_rounded,
                          size: 56,
                          color: Color(0xFF00E5FF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ProctorAI Secure Login',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'student',
                              label: Text('Student'),
                              icon: Icon(Icons.person),
                            ),
                            ButtonSegment(
                              value: 'teacher',
                              label: Text('Teacher'),
                              icon: Icon(Icons.co_present),
                            ),
                            ButtonSegment(
                              value: 'proctor',
                              label: Text('Proctor'),
                              icon: Icon(Icons.admin_panel_settings),
                            ),
                            ButtonSegment(
                              value: 'admin',
                              label: Text('Admin'),
                              icon: Icon(Icons.shield),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (value) {
                            final role = value.first;
                            setState(() {
                              _role = role;
                              if (role == 'teacher') {
                                _usernameController.text = 'teacher';
                                _passwordController.text = 'teacher123';
                              } else if (role == 'proctor') {
                                _usernameController.text = 'proctor';
                                _passwordController.text = 'proctor123';
                              } else if (role == 'admin') {
                                _usernameController.text = 'admin';
                                _passwordController.text = 'admin123';
                              } else {
                                _usernameController.text = 'candidate';
                                _passwordController.text = 'student123';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email or username',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 3
                              ? 'Enter a valid username'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                        ),
                        if (_role == 'student') ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _sideCameraController,
                            decoration: const InputDecoration(
                              labelText: 'Side camera IP:PORT',
                              hintText: '192.168.0.103:8080',
                              prefixIcon: Icon(Icons.settings_input_antenna),
                            ),
                            validator: (value) {
                              if (_role != 'student') return null;
                              return value == null || value.trim().isEmpty
                                  ? 'Enter your side camera IP'
                                  : null;
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _rememberMe,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Remember me'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          _AlertText(message: _error!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_loading ? 'Authenticating' : 'Sign in'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Demo users: candidate / student123, teacher / teacher123, proctor / proctor123',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _sideCameraController.dispose();
    super.dispose();
  }
}

class _AlertText extends StatelessWidget {
  const _AlertText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
