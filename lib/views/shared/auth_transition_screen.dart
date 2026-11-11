import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../customer/customer_shell_screen.dart';
import '../role_router_screen.dart';

/// Animated Full-Screen Loading & Welcome Transition for Accounts.
/// Shown during:
/// 1. Signing in (Credentials or Google One-Tap)
/// 2. Post-Registration onboarding
/// 3. Restoring active logged-in session on boot
class AuthTransitionScreen extends StatefulWidget {
  final StaffAccount user;
  final bool isCustomerApp;
  final bool isAutoLogin;
  final String? customMessage;

  const AuthTransitionScreen({
    super.key,
    required this.user,
    required this.isCustomerApp,
    this.isAutoLogin = false,
    this.customMessage,
  });

  /// Helper route transition with smooth fade
  static Route<void> route({
    required StaffAccount user,
    required bool isCustomerApp,
    bool isAutoLogin = false,
    String? customMessage,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          AuthTransitionScreen(
        user: user,
        isCustomerApp: isCustomerApp,
        isAutoLogin: isAutoLogin,
        customMessage: customMessage,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  State<AuthTransitionScreen> createState() => _AuthTransitionScreenState();
}

class _AuthTransitionScreenState extends State<AuthTransitionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _badgeScaleAnimation;

  bool _isVerified = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _badgeScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _entranceController.forward();
    _startTransitionSequence();
  }

  Future<void> _startTransitionSequence() async {
    final bool isTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    if (!isTest) {
      // Phase 1: Authentication / verification tick
      await Future<void>.delayed(
        Duration(milliseconds: widget.isAutoLogin ? 400 : 700),
      );
      if (mounted) {
        setState(() {
          _isVerified = true;
        });
      }

      // Phase 2: Showcase verified account & welcome greeting
      await Future<void>.delayed(
        Duration(milliseconds: widget.isAutoLogin ? 700 : 900),
      );
    } else {
      if (mounted) {
        setState(() {
          _isVerified = true;
        });
      }
    }

    if (!mounted) return;

    final Widget destination = widget.isCustomerApp
        ? const CustomerShellScreen()
        : const RoleRouterScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = user.fullName.trim().isNotEmpty
        ? user.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
            .join()
        : 'U';

    final roleLabel = widget.isCustomerApp
        ? 'Verified Rider Account'
        : '${user.role.label} • ${user.assignedBranch.displayName}';

    return Scaffold(
      backgroundColor: AppPalette.crust,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Ambient Radial Gold Glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse =
                  0.5 + 0.5 * math.sin(_pulseController.value * 2 * math.pi);
              return Align(
                alignment: Alignment.center,
                child: Container(
                  width: 320 + (pulse * 40),
                  height: 320 + (pulse * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppPalette.champagneGold.withValues(
                          alpha: 0.12 + (pulse * 0.08),
                        ),
                        AppPalette.champagneGold.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Central Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar / Emblem Stack
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating animated gold border ring
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _pulseController.value * 2 * math.pi,
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppPalette.champagneGold
                                          .withValues(alpha: 0.35),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Inner Avatar
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppPalette.mantle,
                              border: Border.all(
                                color: AppPalette.champagneGold,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.champagneGold
                                      .withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: user.photoUrl != null &&
                                      user.photoUrl!.isNotEmpty
                                  ? Image.network(
                                      user.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: AppPalette.champagneGold,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: AppPalette.champagneGold,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 28,
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          // Verified Checkmark Badge
                          if (_isVerified)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: ScaleTransition(
                                scale: _badgeScaleAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppPalette.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppPalette.crust,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppPalette.crust,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Welcome Headline
                      Text(
                        _isVerified
                            ? 'Welcome back,'
                            : (widget.customMessage ?? 'Authenticating...'),
                        style: TextStyle(
                          color: _isVerified
                              ? AppPalette.champagneGold
                              : AppPalette.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        user.fullName.isNotEmpty
                            ? user.fullName
                            : user.username,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppPalette.textHigh,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role & Branch Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.surface1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppPalette.champagneGold
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            color: AppPalette.textHigh,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Indeterminate Gold Loading Progress
                      SizedBox(
                        width: 140,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: AppPalette.surface0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppPalette.champagneGold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isVerified
                                  ? (widget.isCustomerApp
                                      ? 'Loading parts & active repairs...'
                                      : 'Preparing terminal workspace...')
                                  : 'Verifying session token...',
                              style: const TextStyle(
                                color: AppPalette.inactive,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
