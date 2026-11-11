import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/models.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/motohub_viewmodel.dart';
import 'customer_shell_screen.dart';
import '../shared/auth_transition_screen.dart';
import '../shared/forgot_password_screen.dart';
import '../shared/legal_documents_screen.dart';

/// Dedicated Customer Authentication Screen for `main_customer.dart` (App B).
/// Provides:
/// 1. Real Google One-Tap / Google Sign-In flow (persisted in SQLite with `authProvider: 'google'`)
/// 2. Standard Email/Username + Password Sign-In
/// 3. Rider Account Registration
class CustomerAuthScreen extends StatefulWidget {
  const CustomerAuthScreen({super.key});

  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameOrEmailCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  static const String _prefsTermsKey = 'motohub_customer_terms_accepted_v1';

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _checkInitialTermsAcceptance();
  }

  Future<void> _checkInitialTermsAcceptance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accepted = prefs.getBool(_prefsTermsKey) ?? false;
      if (!mounted) return;
      if (accepted) {
        setState(() {
          _acceptedTerms = true;
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_acceptedTerms) {
            _showStartupTermsDialog();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _setTermsAccepted(bool value) async {
    setState(() {
      _acceptedTerms = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsTermsKey, value);
    } catch (_) {}
  }

  void _showStartupTermsDialog() {
    bool dialogChecked = _acceptedTerms;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppPalette.mantle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppPalette.champagneGold, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: AppPalette.champagneGold,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Terms & Privacy Agreement',
                  style: TextStyle(
                    color: AppPalette.champagneGold,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Boss Arman MotoHub. Before continuing, please review and accept our Terms & Conditions and Data Privacy Policy (Republic Act No. 10173).',
                  style: TextStyle(
                    color: AppPalette.textHigh,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.surface0,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Service Bookings & Click-and-Collect orders are subject to branch availability and verification.\n'
                        '• Your profile, vehicle details, and order history are processed securely under RA 10173.\n'
                        '• You may manage or request deletion of your account at any time from your Rider Profile.',
                        style: TextStyle(
                          color: AppPalette.textBody,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          LegalDocumentsScreen.openTermsAndConditions(
                        context,
                        isCustomerApp: true,
                      ),
                      icon: const Icon(Icons.gavel_rounded, size: 15),
                      label: const Text(
                        'Read Terms & Conditions',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => LegalDocumentsScreen.openPrivacyPolicy(
                        context,
                        isCustomerApp: true,
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 15),
                      label: const Text(
                        'Read Privacy Policy',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setDialogState(() {
                      dialogChecked = !dialogChecked;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: dialogChecked,
                            activeColor: AppPalette.champagneGold,
                            checkColor: AppPalette.crust,
                            onChanged: (v) {
                              setDialogState(() {
                                dialogChecked = v ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'I have read and agree to the Terms & Conditions and Privacy Policy (RA 10173).',
                            style: TextStyle(
                              color: AppPalette.textHigh,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.champagneGold,
                foregroundColor: AppPalette.crust,
                disabledBackgroundColor: AppPalette.surface1,
                disabledForegroundColor: AppPalette.textMuted,
              ),
              onPressed: dialogChecked
                  ? () async {
                      Navigator.of(ctx).pop();
                      await _setTermsAccepted(true);
                    }
                  : null,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                'Accept & Continue',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameOrEmailCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPasswordAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Please accept the Terms & Conditions and Privacy Policy to continue.',
            style: TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      _showStartupTermsDialog();
      return;
    }
    final vm = context.read<MotoHubViewModel>();

    try {
      bool ok;
      if (_isRegisterMode) {
        ok = await vm.registerCustomerAccount(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          username: _usernameOrEmailCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          termsVersion: LegalDocumentsScreen.currentTermsVersion,
          termsAcceptedAt: DateTime.now(),
        );
      } else {
        ok = await vm.login(
          _usernameOrEmailCtrl.text.trim(),
          _passwordCtrl.text,
          customerOnly: true,
        );
      }

      if (!mounted) return;
      if (ok) {
        final user = vm.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacement(
            AuthTransitionScreen.route(
              user: user,
              isCustomerApp: true,
              customMessage: _isRegisterMode
                  ? 'Setting up Rider Account...'
                  : 'Authenticating Rider Account...',
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CustomerShellScreen()),
          );
        }
      } else {
        if (vm.statusMessage?.startsWith('ACCOUNT_DELETED_RECOVERABLE') == true) {
          _showRecoverAccountDialog();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              vm.statusMessage ?? 'Authentication failed.',
              style: const TextStyle(color: AppPalette.crust),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Customer auth error: $e',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
    }
  }

  void _showRecoverAccountDialog() {
    final vm = context.read<MotoHubViewModel>();
    final pending = vm.pendingRecoveryAccount;
    if (pending == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.mantle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppPalette.champagneGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: AppPalette.champagneGold, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Restore Deleted Account?',
                style: TextStyle(
                  color: AppPalette.champagneGold,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Account "@${pending.username}" was previously scheduled for deletion, but remains within the 30-day recovery window. Would you like to restore your account and sign in?',
          style: const TextStyle(color: AppPalette.textBody, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppPalette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.champagneGold,
              foregroundColor: AppPalette.crust,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await vm.restoreAccount(pending.id);
              if (!mounted) return;
              if (ok) {
                final loginOk = await vm.login(
                  _usernameOrEmailCtrl.text.trim(),
                  _passwordCtrl.text,
                  customerOnly: true,
                  restoreIfDeleted: true,
                );
                if (loginOk && mounted) {
                  final user = vm.currentUser;
                  if (user != null) {
                    Navigator.of(context).pushReplacement(
                      AuthTransitionScreen.route(
                        user: user,
                        isCustomerApp: true,
                        customMessage: 'Account Restored',
                      ),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CustomerShellScreen()),
                    );
                  }
                }
              }
            },
            child: const Text('Restore & Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleOneTap() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Please accept the Terms & Conditions and Privacy Policy to continue.',
            style: TextStyle(color: AppPalette.crust),
          ),
        ),
      );
      _showStartupTermsDialog();
      return;
    }
    final vm = context.read<MotoHubViewModel>();

    // 1. Attempt native Google One-Tap prompt
    try {
      final googleAccount =
          await FirebaseService.instance.promptNativeGoogleSignIn();

      if (googleAccount == null) {
        return; // User dismissed prompt
      }

      final email = googleAccount['email'] ?? '';
      final name = googleAccount['displayName'] ?? '';
      final photoUrl = googleAccount['photoUrl'];

      final ok = await vm.signInCustomerWithGoogle(
        email: email,
        displayName: name,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      if (ok) {
        final user = vm.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacement(
            AuthTransitionScreen.route(
              user: user,
              isCustomerApp: true,
              customMessage: 'Google One-Tap Verified',
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CustomerShellScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.danger,
            content: Text(
              vm.statusMessage ?? 'Google Sign-In could not complete.',
              style: const TextStyle(color: AppPalette.crust),
            ),
          ),
        );
      }
      return;
    } catch (e) {
      debugPrint('[CustomerAuthScreen] Native Google Sign-In notice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.danger,
          content: Text(
            'Google Sign-In failed: $e',
            style: const TextStyle(color: AppPalette.crust),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();

    return Scaffold(
      backgroundColor: AppPalette.crust,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Emblem
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppPalette.mantle,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppPalette.champagneGold
                                    .withValues(alpha: 0.45),
                                width: 1.4,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.asset(
                                  'assets/images/customer_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.two_wheeler_rounded,
                                    color: AppPalette.champagneGold,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Boss Arman MotoHub',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Customer Service Tracking, Appointments & Click-and-Collect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mode Toggle: Sign In vs Create Account
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: SlidingMarqueeText(text: 'Rider Sign In'),
                              icon: Icon(Icons.login_rounded, size: 16),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: SlidingMarqueeText(text: 'Create Account'),
                              icon:
                                  Icon(Icons.person_add_alt_1_rounded, size: 16),
                            ),
                          ],
                          selected: {_isRegisterMode},
                          onSelectionChanged: (set) {
                            setState(() {
                              _isRegisterMode = set.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Google One-Tap / Google Sign-In CTA Card
                        Card.filled(
                          color: AppPalette.mantle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppPalette.champagneGold
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: vm.viewState == ViewState.loading
                                ? null
                                : _handleGoogleOneTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppPalette.surface1,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color: AppPalette.champagneGold,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Continue with Google One-Tap',
                                          style: TextStyle(
                                            color: AppPalette.textHigh,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          'Instant rider sign-in for service & parts reservation',
                                          style: TextStyle(
                                            color: AppPalette.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 15,
                                    color: AppPalette.champagneGold,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                _isRegisterMode
                                    ? 'OR REGISTER WITH EMAIL'
                                    : 'OR SIGN IN WITH PASSWORD',
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_isRegisterMode) ...[
                          LayoutBuilder(
                            builder: (context, innerConstraints) {
                              final isCompact = innerConstraints.maxWidth < 360;
                              final firstField = TextFormField(
                                controller: _firstNameCtrl,
                                maxLength: 30,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(30),
                                ],
                                validator: (v) => AppValidators.name(
                                  v,
                                  'First name',
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                              );
                              final lastField = TextFormField(
                                controller: _lastNameCtrl,
                                maxLength: 30,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(30),
                                ],
                                validator: (v) => AppValidators.name(
                                  v,
                                  'Last name',
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              );
                              if (isCompact) {
                                return Column(
                                  children: [
                                    firstField,
                                    const SizedBox(height: 12),
                                    lastField,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: firstField),
                                  const SizedBox(width: 12),
                                  Expanded(child: lastField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextFormField(
                          controller: _usernameOrEmailCtrl,
                          validator: _isRegisterMode
                              ? AppValidators.username
                              : (v) => AppValidators.requiredField(
                                    v,
                                    'Username or email',
                                  ),
                          decoration: InputDecoration(
                            labelText: _isRegisterMode
                                ? 'Rider Username'
                                : 'Username or Email',
                            hintText: _isRegisterMode
                                ? 'e.g. juan.rider'
                                : 'Enter your username or email',
                            prefixIcon:
                                const Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isRegisterMode) ...[
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: AppValidators.email,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'rider@email.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          validator: AppValidators.password,
                          onFieldSubmitted: (_) => _submitEmailPasswordAuth(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (!_isRegisterMode) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => ForgotPasswordScreen.navigate(
                                context,
                                initialEmail:
                                    _usernameOrEmailCtrl.text.contains('@')
                                        ? _usernameOrEmailCtrl.text.trim()
                                        : null,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppPalette.champagneGold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.mantle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _acceptedTerms
                                  ? AppPalette.champagneGold
                                      .withValues(alpha: 0.6)
                                  : AppPalette.surface0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: AppPalette.champagneGold,
                                  checkColor: AppPalette.crust,
                                  onChanged: (v) =>
                                      _setTermsAccepted(v ?? false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'I have read and agree to the ',
                                      style: TextStyle(
                                        color: AppPalette.textBody,
                                        fontSize: 12,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => LegalDocumentsScreen
                                          .openTermsAndConditions(
                                        context,
                                        isCustomerApp: true,
                                      ),
                                      child: const Text(
                                        'Terms & Conditions',
                                        style: TextStyle(
                                          color: AppPalette.champagneGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' and ',
                                      style: TextStyle(
                                        color: AppPalette.textBody,
                                        fontSize: 12,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => LegalDocumentsScreen
                                          .openPrivacyPolicy(
                                        context,
                                        isCustomerApp: true,
                                      ),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: AppPalette.champagneGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' (RA 10173).',
                                      style: TextStyle(
                                        color: AppPalette.textBody,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        GoldGradientButton(
                          label: _isRegisterMode
                              ? 'Create Rider Account'
                              : 'Sign In to Rider Portal',
                          icon: _isRegisterMode
                              ? Icons.how_to_reg_rounded
                              : Icons.login_rounded,
                          isLoading: vm.viewState == ViewState.loading,
                          onPressed: _submitEmailPasswordAuth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
