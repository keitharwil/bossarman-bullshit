import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Material 3 Expressive motion tokens + reusable animated widgets.
class M3EMotion {
  M3EMotion._();

  static const Duration short1 = Duration(milliseconds: 50);
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short3 = Duration(milliseconds: 150);
  static const Duration short4 = Duration(milliseconds: 200);
  static const Duration medium1 = Duration(milliseconds: 250);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium3 = Duration(milliseconds: 350);
  static const Duration medium4 = Duration(milliseconds: 400);
  static const Duration long1 = Duration(milliseconds: 450);
  static const Duration long2 = Duration(milliseconds: 500);
  static const Duration long3 = Duration(milliseconds: 550);
  static const Duration long4 = Duration(milliseconds: 600);

  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve springOvershoot = Cubic(0.2, 0.9, 0.1, 1.15);
  static const Curve springBounce = Cubic(0.34, 1.56, 0.64, 1.0);
}

// ---------------------------------------------------------------------------
// 1. PAGE TRANSITIONS — applied at theme level so EVERY pushed route animates
// ---------------------------------------------------------------------------

class M3EPageTransitionsBuilder extends PageTransitionsBuilder {
  const M3EPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: M3EMotion.emphasizedDecelerate,
      reverseCurve: M3EMotion.emphasizedAccelerate,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Explicit fade-through route (used when you want to force the M3E feel
/// on a specific navigation call).
class M3EFadeThroughRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  M3EFadeThroughRoute({required this.child})
      : super(
          transitionDuration: M3EMotion.long2,
          reverseTransitionDuration: M3EMotion.medium4,
          pageBuilder: (_, _, _) => child,
          transitionsBuilder: (_, animation, _, pageChild) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: M3EMotion.emphasizedDecelerate,
            );
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
                  child: pageChild,
                ),
              ),
            );
          },
        );
}

// ---------------------------------------------------------------------------
// 2. TAB SWITCHER — animates between bottom-nav destinations
// ---------------------------------------------------------------------------

/// Wraps the `body:` of a Scaffold to animate tab content changes.
/// Every shell (Admin, Cashier, Mechanic, Customer) gets this for free.
class M3ETabSwitcher extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const M3ETabSwitcher({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, children.length - 1);
    return AnimatedSwitcher(
      duration: M3EMotion.medium4,
      switchInCurve: M3EMotion.emphasizedDecelerate,
      switchOutCurve: M3EMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(safeIndex),
        child: children[safeIndex],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. PRESSABLE CARD — scale feedback on tap (feels tactile like iOS/M3E)
// ---------------------------------------------------------------------------

class M3EPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const M3EPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<M3EPressable> createState() => _M3EPressableState();
}

class _M3EPressableState extends State<M3EPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: M3EMotion.short4,
      reverseDuration: M3EMotion.short4,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final scale = 1.0 -
              ((1.0 - widget.pressedScale) *
                  M3EMotion.emphasizedDecelerate.transform(_c.value));
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. SPRING IN — staggered entrance for list items
// ---------------------------------------------------------------------------

class M3ESpringIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Offset fromOffset;

  const M3ESpringIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 45),
    this.fromOffset = const Offset(0, 0.12),
  });

  @override
  State<M3ESpringIn> createState() => _M3ESpringInState();
}

class _M3ESpringInState extends State<M3ESpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: M3EMotion.long1);
    _fade = CurvedAnimation(parent: _c, curve: M3EMotion.emphasizedDecelerate);
    _slide = Tween<Offset>(begin: widget.fromOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: M3EMotion.springOvershoot));
    _scale = Tween<double>(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: M3EMotion.springOvershoot));

    final delay = widget.baseDelay * widget.index.clamp(0, 12);
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. ANIMATED COUNTER — rolls numbers up from 0
// ---------------------------------------------------------------------------

class M3EAnimatedCounter extends StatelessWidget {
  final double value;
  final Duration duration;
  final Widget Function(BuildContext, double) builder;

  const M3EAnimatedCounter({
    super.key,
    required this.value,
    this.duration = M3EMotion.long2,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: M3EMotion.emphasizedDecelerate,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. PULSE BUTTON — breathing glow for primary CTAs
// ---------------------------------------------------------------------------

class M3EPulseButton extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const M3EPulseButton({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<M3EPulseButton> createState() => _M3EPulseButtonState();
}

class _M3EPulseButtonState extends State<M3EPulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant M3EPulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 1.0 + (t * 0.018);
        final glow = 0.10 + (t * 0.12);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: AppPalette.champagneGold.withValues(alpha: glow),
                        blurRadius: 16 + (t * 8),
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// 7. RECEIPT PRINTER — for Z-Reading dialogs
// ---------------------------------------------------------------------------

class M3EReceiptPrinter extends StatefulWidget {
  final Widget child;
  const M3EReceiptPrinter({super.key, required this.child});

  @override
  State<M3EReceiptPrinter> createState() => _M3EReceiptPrinterState();
}

class _M3EReceiptPrinterState extends State<M3EReceiptPrinter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: M3EMotion.long3);
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: M3EMotion.emphasizedDecelerate),
    );
    _fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _scale.value.clamp(0.001, 1.0),
              child: child,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
