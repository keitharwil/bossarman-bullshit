import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// An expressive text widget that automatically detects whether text overflows
/// its container's available width.
///
/// - If the text fits, it renders cleanly with zero animation overhead.
/// - If the text overflows its available width and cannot be expanded (e.g. inside
///   segmented buttons, tabs, or badges), it smoothly slides horizontally back and forth
///   (marquee ping-pong) with gentle pauses at both ends so the user can read ALL letters
///   without permanent ellipsis truncation.
///
/// Built with a custom [RenderBox] that properly implements intrinsic dimensions
/// (`computeMinIntrinsicWidth`, `computeMaxIntrinsicWidth`), making it fully compatible
/// with Flutter's [SegmentedButton], [Row], and table headers without throwing
/// "LayoutBuilder does not support returning intrinsic dimensions" assertions.
class SlidingMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration pauseDuration;
  final double pixelsPerSecond;

  const SlidingMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.pauseDuration = const Duration(milliseconds: 1400),
    this.pixelsPerSecond = 32.0,
  });

  @override
  State<SlidingMarqueeText> createState() => _SlidingMarqueeTextState();
}

class _SlidingMarqueeTextState extends State<SlidingMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  double _currentDelta = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Normalized ping-pong animation curve:
    // 0% -> 22%: Pause at start (offset = 0)
    // 22% -> 50%: Smooth cubic ease-in-out to end (offset = delta)
    // 50% -> 72%: Pause at end (offset = delta)
    // 72% -> 100%: Smooth cubic ease-in-out back to start (offset = 0)
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 22.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 22.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleOverflowChanged(double delta) {
    if ((_currentDelta - delta).abs() < 0.5) return;
    _currentDelta = delta;

    if (delta <= 0) {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.reset();
      }
      return;
    }

    final scrollDurationMs =
        (delta / widget.pixelsPerSecond * 1000).clamp(1200, 5000).toInt();
    final pauseMs = widget.pauseDuration.inMilliseconds;
    final totalCycleMs = (scrollDurationMs * 2) + (pauseMs * 2);

    _controller.duration = Duration(milliseconds: totalCycleMs);
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = widget.style ?? defaultStyle;
    final direction = Directionality.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return _SlidingMarqueeRenderObjectWidget(
          text: widget.text,
          style: effectiveStyle,
          textAlign: widget.textAlign,
          textDirection: direction,
          offsetFactor: _animation.value,
          onOverflowChanged: (delta) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _handleOverflowChanged(delta);
            });
          },
        );
      },
    );
  }
}

class _SlidingMarqueeRenderObjectWidget extends LeafRenderObjectWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double offsetFactor;
  final ValueChanged<double> onOverflowChanged;

  const _SlidingMarqueeRenderObjectWidget({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.offsetFactor,
    required this.onOverflowChanged,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSlidingMarquee(
      text: text,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      offsetFactor: offsetFactor,
      onOverflowChanged: onOverflowChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSlidingMarquee renderObject,
  ) {
    renderObject
      ..text = text
      ..style = style
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..offsetFactor = offsetFactor
      ..onOverflowChanged = onOverflowChanged;
  }
}

class _RenderSlidingMarquee extends RenderBox {
  String _text;
  TextStyle _style;
  TextAlign _textAlign;
  TextDirection _textDirection;
  double _offsetFactor;
  ValueChanged<double> _onOverflowChanged;

  final TextPainter _textPainter;
  double _lastDelta = -1.0;

  _RenderSlidingMarquee({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required this._offsetFactor,
    required this._onOverflowChanged,
  })  : _text = text,
        _style = style,
        _textAlign = textAlign,
        _textDirection = textDirection,
        _textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: textAlign,
          textDirection: textDirection,
          maxLines: 1,
        );

  set text(String value) {
    if (_text == value) return;
    _text = value;
    _textPainter.text = TextSpan(text: _text, style: _style);
    markNeedsLayout();
  }

  set style(TextStyle value) {
    if (_style == value) return;
    _style = value;
    _textPainter.text = TextSpan(text: _text, style: _style);
    markNeedsLayout();
  }

  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    _textPainter.textAlign = _textAlign;
    markNeedsPaint();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _textPainter.textDirection = _textDirection;
    markNeedsLayout();
  }

  set offsetFactor(double value) {
    if (_offsetFactor == value) return;
    _offsetFactor = value;
    markNeedsPaint();
  }

  set onOverflowChanged(ValueChanged<double> value) {
    _onOverflowChanged = value;
  }

  void _layoutPainter() {
    _textPainter.layout(minWidth: 0, maxWidth: double.infinity);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutPainter();
    return _textPainter.width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutPainter();
    return _textPainter.width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutPainter();
    return _textPainter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _layoutPainter();
    return _textPainter.height;
  }

  @override
  void performLayout() {
    _layoutPainter();
    final textWidth = _textPainter.width;
    final textHeight = _textPainter.height;

    final double width;
    if (constraints.hasBoundedWidth) {
      width = constraints.maxWidth;
    } else {
      width = textWidth;
    }

    size = constraints.constrain(Size(width, textHeight));

    final delta = max(0.0, textWidth - size.width);
    if ((_lastDelta - delta).abs() > 0.5) {
      _lastDelta = delta;
      _onOverflowChanged(delta);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _layoutPainter();
    final delta = max(0.0, _textPainter.width - size.width);

    if (delta <= 0.5) {
      _textPainter.paint(context.canvas, offset);
      return;
    }

    final scrollOffset = _offsetFactor * delta;
    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, 0, size.width, size.height),
      (context, offset) {
        _textPainter.paint(
          context.canvas,
          offset.translate(-scrollOffset, 0),
        );
      },
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _text
      ..textDirection = _textDirection;
  }
}
