import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_state.dart';

/// Accessible, high-contrast Authentication Screen for the Unified SAHAYAK Platform.
///
/// Supports:
/// - Unified Login (`POST /api/v1/auth/login` for USER and PARENT accounts)
/// - Account Registration (`POST /api/v1/auth/register` restricted to `USER` or `PARENT`, never `ADMIN`)
class AuthScreen extends StatefulWidget {
  final AuthController authController;

  const AuthScreen({
    super.key,
    required this.authController,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isRegisterMode = false;
  String _selectedRegisterRole = 'USER';
  String? _localValidationError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() {
      _localValidationError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localValidationError = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _localValidationError = 'Password must be at least 8 characters.';
      });
      return;
    }

    if (_isRegisterMode) {
      if (fullName.isEmpty) {
        setState(() {
          _localValidationError = 'Full name is required for registration.';
        });
        return;
      }
      final safeRole = _selectedRegisterRole == 'PARENT' ? 'PARENT' : 'USER';
      await widget.authController.register(
        fullName: fullName,
        email: email,
        password: password,
        phoneNumber: _phoneController.text.trim(),
        role: safeRole,
      );
    } else {
      await widget.authController.login(
        email: email,
        password: password,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final authState = widget.authController.state;
        final isBusy = authState.status == AuthStatus.authenticating ||
            authState.status == AuthStatus.refreshing;
        final errorBanner = _localValidationError ?? authState.errorMessage;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isRegisterMode
                  ? 'SAHAYAK — Register Account'
                  : 'SAHAYAK — User Sign In',
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      label: _isRegisterMode
                          ? 'Create a SAHAYAK Account'
                          : 'Sign in to SAHAYAK Platform',
                      child: Text(
                        _isRegisterMode
                            ? (_selectedRegisterRole == 'PARENT'
                                ? 'Create Caregiver (Parent) Account'
                                : 'Create Stick User Account')
                            : 'Sign In to Stick User Module',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegisterMode
                          ? 'Select Stick User (USER) or Caregiver (PARENT) role below.'
                          : 'Sign in with your Stick User or Caregiver (Parent) credentials.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (errorBanner != null && errorBanner.isNotEmpty) ...[
                      Semantics(
                        liveRegion: true,
                        label: 'Authentication Error: $errorBanner',
                        child: Container(
                          key: const Key('auth_error_banner'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E1018),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorBanner,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_isRegisterMode) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: _selectedRegisterRole == 'USER',
                              label: 'Register as Stick User',
                              child: OutlinedButton.icon(
                                key: const Key('auth_role_user_button'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedRegisterRole = 'USER';
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      _selectedRegisterRole == 'USER'
                                          ? const Color(0xFF00E5FF)
                                          : Colors.transparent,
                                  foregroundColor:
                                      _selectedRegisterRole == 'USER'
                                          ? Colors.black
                                          : Colors.white,
                                ),
                                icon: const Icon(Icons.accessibility_new),
                                label: const Text('STICK USER'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: _selectedRegisterRole == 'PARENT',
                              label: 'Register as Caregiver Parent',
                              child: OutlinedButton.icon(
                                key: const Key('auth_role_parent_button'),
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedRegisterRole = 'PARENT';
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      _selectedRegisterRole == 'PARENT'
                                          ? const Color(0xFF00E5FF)
                                          : Colors.transparent,
                                  foregroundColor:
                                      _selectedRegisterRole == 'PARENT'
                                          ? Colors.black
                                          : Colors.white,
                                ),
                                icon: const Icon(Icons.family_restroom),
                                label: const Text('CAREGIVER'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth_full_name_field'),
                        controller: _fullNameController,
                        enabled: !isBusy,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const Key('auth_email_field'),
                      controller: _emailController,
                      enabled: !isBusy,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'user@sahayak.local',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('auth_password_field'),
                      controller: _passwordController,
                      enabled: !isBusy,
                      obscureText: true,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: 'Minimum 8 characters',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_isRegisterMode) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth_phone_field'),
                        controller: _phoneController,
                        enabled: !isBusy,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: '+91 9876543210',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: _isRegisterMode
                          ? 'Submit Account Registration'
                          : 'Submit Sign In',
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          key: const Key('auth_submit_button'),
                          onPressed: isBusy ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          icon: Icon(
                            _isRegisterMode ? Icons.person_add : Icons.login,
                            size: 26,
                          ),
                          label: Text(
                            isBusy
                                ? 'PLEASE WAIT...'
                                : (_isRegisterMode
                                    ? (_selectedRegisterRole == 'PARENT'
                                        ? 'CREATE CAREGIVER ACCOUNT'
                                        : 'CREATE USER ACCOUNT')
                                    : 'SIGN IN'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: _isRegisterMode
                          ? 'Switch to Sign In Mode'
                          : 'Switch to Create Account Mode',
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          key: const Key('auth_toggle_mode_button'),
                          onPressed: isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _isRegisterMode = !_isRegisterMode;
                                    _localValidationError = null;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 2),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            _isRegisterMode
                                ? 'ALREADY HAVE AN ACCOUNT? SIGN IN'
                                : 'NEW USER? CREATE ACCOUNT',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
