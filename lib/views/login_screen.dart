import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/models.dart';
import '../core/services/firebase_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../viewmodels/motohub_viewmodel.dart';
import 'role_router_screen.dart';
import 'shared/auth_transition_screen.dart';
import 'shared/forgot_password_screen.dart';
import 'shared/legal_documents_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _prefsTermsKey = 'motohub_internal_terms_accepted_v1';

  // Direct credentials login form ("Type and connect" + Google One-Tap)
  bool _showCredentialsForm = true;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
                  'Staff Terms & Privacy Agreement',
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
                  'Before accessing the Boss Arman MotoHub ERP/POS Terminal, please review and accept our Internal Terms & Conditions and Data Privacy Policy (Republic Act No. 10173).',
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
                        '• Authorized use only: All POS transactions, stock transfers, and job orders are logged.\n'
                        '• Customer and employee records are protected under RA 10173.\n'
                        '• Do not share your staff credentials or leave an unlocked terminal unattended.',
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
                        isCustomerApp: false,
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
                        isCustomerApp: false,
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

  Widget _buildTermsAcceptanceBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.mantle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _acceptedTerms
              ? AppPalette.champagneGold.withValues(alpha: 0.6)
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
              onChanged: (v) => _setTermsAccepted(v ?? false),
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
                  onTap: () => LegalDocumentsScreen.openTermsAndConditions(
                    context,
                    isCustomerApp: false,
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
                  onTap: () => LegalDocumentsScreen.openPrivacyPolicy(
                    context,
                    isCustomerApp: false,
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
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
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
      final ok = await vm.login(
        _usernameController.text.trim(),
        _passwordController.text,
        customerOnly: false,
      );

      if (!mounted) return;
      if (ok) {
        final user = vm.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacement(
            AuthTransitionScreen.route(
              user: user,
              isCustomerApp: false,
              customMessage: 'Accessing Staff Terminal...',
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoleRouterScreen()),
          );
        }
      } else {
        if (vm.statusMessage?.startsWith('ACCOUNT_DELETED_RECOVERABLE') == true) {
          _showRecoverAccountDialog();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface1,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppPalette.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vm.statusMessage ?? 'Invalid login credentials',
                    style: const TextStyle(color: AppPalette.textHigh),
                  ),
                ),
              ],
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
            'Authentication error: $e',
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
          'Account "@${pending.username}" was previously scheduled for deletion, but remains within the 30-day recovery window. Would you like to restore this account and log in?',
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
                  _usernameController.text.trim(),
                  _passwordController.text,
                  customerOnly: false,
                  restoreIfDeleted: true,
                );
                if (loginOk && mounted) {
                  final user = vm.currentUser;
                  if (user != null) {
                    Navigator.of(context).pushReplacement(
                      AuthTransitionScreen.route(
                        user: user,
                        isCustomerApp: false,
                        customMessage: 'Account Restored',
                      ),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RoleRouterScreen()),
                    );
                  }
                }
              }
            },
            child: const Text('Restore & Log In'),
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

    // 1. Attempt native Google One-Tap / Sign-In prompt
    try {
      final googleAccount =
          await FirebaseService.instance.promptNativeGoogleSignIn();

      if (googleAccount == null) {
        // User closed or cancelled the native Google account picker
        return;
      }

      final email = googleAccount['email'] ?? '';
      final name = googleAccount['displayName'] ?? '';
      final photoUrl = googleAccount['photoUrl'];

      final ok = await vm.signInStaffWithGoogle(
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
              isCustomerApp: false,
              customMessage: 'Google One-Tap Verified',
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoleRouterScreen()),
          );
        }
      } else {
        _showAccessDeniedDialog(email);
      }
      return;
    } catch (e) {
      debugPrint('[LoginScreen] Native Google Sign-In notice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.surface1,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppPalette.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Google Sign-In failed: $e',
                  style: const TextStyle(color: AppPalette.textHigh),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showAccessDeniedDialog(String email) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.mantle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppPalette.danger, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad_rounded, color: AppPalette.danger, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Access Denied: Account Not Found',
                style: TextStyle(
                  color: AppPalette.danger,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'The Google email "${email.trim()}" is not registered by the Admin as an authorized staff account.\n\nPlease contact Boss Arman Sarita to provision your email in the Admin Panel before using Google One-Tap.',
          style: const TextStyle(
            color: AppPalette.textHigh,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.crust,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();

    return Scaffold(
      backgroundColor: AppPalette.crust,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _showCredentialsForm
                  ? _buildCredentialsStep(context, vm)
                  : _buildTerminalLandingStep(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  /// Screen 2 from User's Figma Image:
  /// "Staff & Management" / "Choose an action to access the terminal." / "Log In to Account"
  Widget _buildTerminalLandingStep(
    BuildContext context,
    MotoHubViewModel vm,
  ) {
    return LayoutBuilder(
      key: const ValueKey('landing_step'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 8),
                Column(
                  children: [
                    // Rounded Square Icon Box with Gold Ring
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppPalette.mantle,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppPalette.warmGold.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.champagneGold.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/admin_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.handyman_rounded,
                              color: AppPalette.champagneGold,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Staff & Management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an action to access the internal ERP/POS terminal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                Column(
                  children: [
                    // Google One-Tap Card for Staff
                    Card.filled(
                      color: AppPalette.mantle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppPalette.champagneGold.withValues(alpha: 0.4),
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
                                  shape: BoxShape.circle,
                                  color: AppPalette.surface1,
                                  border: Border.all(
                                    color: AppPalette.champagneGold.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: AppPalette.champagneGold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'Instant staff sign-in for registered emails',
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
                                size: 14,
                                color: AppPalette.champagneGold,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divider: OR SIGN IN WITH USERNAME & PASSWORD
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppPalette.surface0)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR SIGN IN WITH PASSWORD',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppPalette.surface0)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Primary CTA Button: Log In to Account
                    GoldGradientButton(
                      label: 'Log In to Account',
                      icon: Icons.login_rounded,
                      onPressed: () {
                        setState(() {
                          _showCredentialsForm = true;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Terminal ID: ${vm.activeBranch.terminalId} • SQLite ACID Engine Ready',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.inactive,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTermsAcceptanceBox(context),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Screen 3 from User's Figma Image:
  /// "← Staff Login" / "What's your username and password?" / Outlined Gold Input / "Next →"
  Widget _buildCredentialsStep(
    BuildContext context,
    MotoHubViewModel vm,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('credentials_step'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Back Navigation: "← Staff Login"
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _showCredentialsForm = false;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      color: AppPalette.textBody,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Staff Login',
                      style: TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "What's your username and\npassword?",
              style: TextStyle(
                color: AppPalette.textHigh,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your registered internal staff username and password to connect.',
              style: TextStyle(
                color: AppPalette.textMuted,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 22),

            // Custom Outlined Gold Input Box for Username (Matching Figma frame)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.mantle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppPalette.warmGold.withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppPalette.champagneGold,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _usernameController,
                      validator: AppValidators.username,
                      style: const TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: 'Enter store username',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Custom Outlined Input Box for Password
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.mantle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppPalette.surface0,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppPalette.champagneGold,
                    size: 21,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: AppValidators.password,
                      onFieldSubmitted: (_) => _submitLogin(),
                      style: const TextStyle(
                        color: AppPalette.textHigh,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(
                          color: AppPalette.champagneGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: 'Enter store password',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                            color: AppPalette.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ForgotPasswordScreen.navigate(context),
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
            const SizedBox(height: 12),
            _buildTermsAcceptanceBox(context),
            const SizedBox(height: 16),

            // Bottom "Next ->" Gold Gradient Button matching User's Figma Design
            GoldGradientButton(
              label: 'Next →',
              isLoading: vm.viewState == ViewState.loading,
              onPressed: _submitLogin,
            ),
            const SizedBox(height: 14),

            // Alternative: Sign in with Google One-Tap
            Center(
              child: TextButton.icon(
                onPressed: _handleGoogleOneTap,
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.surface1,
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: AppPalette.champagneGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                label: const Text(
                  'Or sign in with Google One-Tap',
                  style: TextStyle(
                    color: AppPalette.champagneGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
