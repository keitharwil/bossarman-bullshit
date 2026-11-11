import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';

/// Password recovery using the standard Firebase Auth reset email.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  static Future<void> navigate(BuildContext context, {String? initialEmail}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: initialEmail),
      ),
    );
  }

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _cooldownSeconds = 45;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _sent = false;
  Timer? _cooldownTimer;
  int _remainingCooldown = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmail;
    if (initial != null && initial.isNotEmpty) {
      _emailController.text = initial;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _remainingCooldown = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingCooldown <= 1) {
        timer.cancel();
        setState(() => _remainingCooldown = 0);
      } else {
        setState(() => _remainingCooldown--);
      }
    });
  }

  Future<void> _send() async {
    if (_isLoading || _remainingCooldown > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final vm = context.read<MotoHubViewModel>();
    setState(() => _isLoading = true);
    try {
      await vm.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } on AuthFlowException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            message,
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.crust,
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 56,
            color: AppPalette.champagneGold,
          ),
          const SizedBox(height: 16),
          const Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.textBody,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the email linked to your account and we will send you a link to choose a new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: AppValidators.email,
            onFieldSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _send,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: AppPalette.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Check your email for the reset link',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.textBody,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a password reset link to ${_emailController.text.trim()}. '
          'Open it, choose a new password, then sign in. '
          'If you do not see it, check your spam folder.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Back to Login'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_isLoading || _remainingCooldown > 0) ? null : _send,
          child: Text(
            _remainingCooldown > 0
                ? 'Resend email in ${_remainingCooldown}s'
                : 'Resend email',
          ),
        ),
      ],
    );
  }
}
