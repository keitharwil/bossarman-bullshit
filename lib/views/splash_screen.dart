import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../viewmodels/motohub_viewmodel.dart';
import 'customer/customer_auth_screen.dart';
import 'login_screen.dart';
import 'shared/auth_transition_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isCustomerApp;

  const SplashScreen({
    super.key,
    this.isCustomerApp = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScaleAnim;
  late final Animation<double> _logoFadeAnim;
  late final Animation<Offset> _footerSlideAnim;
  late final Animation<double> _footerFadeAnim;

  @override
  void initState() {
    super.initState();

    // Primary entrance choreography (logo spring scale + footer rise)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoFadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );

    _logoScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30,
      ),
    ]).animate(_entranceController);

    _footerFadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _footerSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Continuous ambient halo & 3-dot wave animation (no progress bar or % text)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _entranceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootSequence();
    });
  }

  Future<void> _bootSequence() async {
    final vm = context.read<MotoHubViewModel>();
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final minSplashDuration = isTest
        ? Future<void>.value()
        : Future<void>.delayed(const Duration(milliseconds: 1500));

    await Future.wait([
      vm.initializeApp(),
      minSplashDuration,
    ]);

    if (!mounted) return;

    if (vm.currentUser != null) {
      Navigator.of(context).pushReplacement(
        AuthTransitionScreen.route(
          user: vm.currentUser!,
          isCustomerApp: widget.isCustomerApp,
          isAutoLogin: true,
          customMessage: 'Session Restored',
        ),
      );
      return;
    }

    final Widget destination = widget.isCustomerApp
        ? const CustomerAuthScreen()
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.crust,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle Animated Ambient Radial Gold Glow in True Center
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse =
                  0.5 + 0.5 * math.sin(_pulseController.value * 2 * math.pi);
              return Align(
                alignment: Alignment.center,
                child: Container(
                  width: 360 + (pulse * 32),
                  height: 360 + (pulse * 32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppPalette.champagneGold
                            .withValues(alpha: 0.11 + (pulse * 0.05)),
                        AppPalette.warmGold.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // TRUE CENTERPIECE: Medium-Sized Iconic Logo + Animated Halo Rings
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _logoFadeAnim,
                child: ScaleTransition(
                  scale: _logoScaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 256,
                        height: 256,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Animated Expanding Ripple Rings
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                return CustomPaint(
                                  size: const Size(256, 256),
                                  painter: _EmblemHaloPainter(
                                    progress: _pulseController.value,
                                  ),
                                );
                              },
                            ),

                            // Medium-Sized Elevated Luxury Emblem Badge (184x184)
                            Container(
                              width: 184,
                              height: 184,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.mantle,
                                border: Border.all(
                                  color: AppPalette.champagneGold
                                      .withValues(alpha: 0.65),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.champagneGold
                                        .withValues(alpha: 0.18),
                                    blurRadius: 36,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: Image.asset(
                                      widget.isCustomerApp
                                          ? 'assets/images/customer_logo.png'
                                          : 'assets/images/admin_logo.png',
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          widget.isCustomerApp
                                              ? Icons.two_wheeler_rounded
                                              : Icons.handyman_rounded,
                                          size: 82,
                                          color: AppPalette.champagneGold,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Minimalist 3-Dot Wave Indicator (Facebook/Meta style, no % bar)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (index) {
                              final phase =
                                  (_pulseController.value * 2 * math.pi) -
                                      (index * 0.85);
                              final wave = (math.sin(phase) + 1) / 2;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4.5,
                                ),
                                width: 7 + (wave * 2.5),
                                height: 7 + (wave * 2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppPalette.champagneGold.withValues(
                                    alpha: 0.30 + (wave * 0.70),
                                  ),
                                  boxShadow: [
                                    if (wave > 0.65)
                                      BoxShadow(
                                        color: AppPalette.champagneGold
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                  ],
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // FOOTER: Facebook/Meta-Style Minimalist Brand Signature Anchored at Bottom
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: SlideTransition(
                  position: _footerSlideAnim,
                  child: FadeTransition(
                    opacity: _footerFadeAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'from',
                          style: TextStyle(
                            color: AppPalette.textMuted.withValues(alpha: 0.75),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Boss Arman MotoHub',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppPalette.champagneGold,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isCustomerApp
                              ? 'App B • Rider Facing Companion Application'
                              : 'App A • Internal ERP, POS & Bay Management',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SANTA CRUZ, LAGUNA • PATIMBAO & P. GUEVARA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppPalette.inactive.withValues(alpha: 0.85),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
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

class _EmblemHaloPainter extends CustomPainter {
  final double progress;

  const _EmblemHaloPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 92.0;
    final maxRadius = size.width / 2;

    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final radius = baseRadius + ((maxRadius - baseRadius) * ringProgress);
      final alpha = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.32;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppPalette.champagneGold.withValues(alpha: alpha);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemHaloPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
