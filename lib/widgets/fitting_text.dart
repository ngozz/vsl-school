import 'package:flutter/material.dart';

/// Text that picks the largest font size that still fits [maxLines].
///
/// It starts at [maxFontSize] and shrinks down to [minFontSize] in 0.5pt
/// steps. If the text still does not fit at [minFontSize], it is rendered at
/// that size with [overflow] applied, so a pathological title degrades
/// gracefully instead of overflowing its card.
///
/// Measurement uses the current [MediaQuery.textScalerOf], so the result stays
/// correct when the user changes the system text size or rotates the device.
class FittingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final double minFontSize;
  final double maxFontSize;
  final TextAlign? textAlign;
  final TextOverflow overflow;

  const FittingText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 3,
    this.minFontSize = 12,
    this.maxFontSize = 15,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  State<FittingText> createState() => _FittingTextState();
}

class _FittingTextState extends State<FittingText> {
  String? _lastText;
  TextStyle? _lastStyle;
  double? _lastWidth;
  double? _lastScale;
  double? _lastSize;

  double _fit({
    required String text,
    required TextStyle style,
    required double width,
    required TextScaler scaler,
  }) {
    // Cheap cache: the list rebuilds on download updates, and re-measuring
    // every visible title would be wasted work.
    final scaleKey = scaler.scale(widget.maxFontSize);
    final cached = _lastSize;
    if (cached != null &&
        _lastText == text &&
        _lastStyle == style &&
        _lastWidth == width &&
        _lastScale == scaleKey) {
      return cached;
    }

    bool fits(double size) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
        maxLines: widget.maxLines,
        textAlign: widget.textAlign ?? TextAlign.start,
        textDirection: Directionality.of(context),
        textScaler: scaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: width);
      final ok = !painter.didExceedMaxLines;
      painter.dispose();
      return ok;
    }

    double size;
    if (fits(widget.maxFontSize)) {
      size = widget.maxFontSize;
    } else if (!fits(widget.minFontSize)) {
      size = widget.minFontSize;
    } else {
      var low = widget.minFontSize;
      var high = widget.maxFontSize;
      for (var i = 0; i < 6; i++) {
        final mid = (low + high) / 2;
        if (fits(mid)) {
          low = mid;
        } else {
          high = mid;
        }
      }
      // Snap down to a half point so neighbouring cards do not show
      // imperceptibly different sizes.
      size = (low * 2).floorToDouble() / 2;
    }

    _lastText = text;
    _lastStyle = style;
    _lastWidth = width;
    _lastScale = scaleKey;
    _lastSize = size;
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        DefaultTextStyle.of(context)
            .style
            .copyWith(fontSize: widget.maxFontSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final size = width.isFinite
            ? _fit(
                text: widget.text,
                style: style,
                width: width,
                scaler: MediaQuery.textScalerOf(context),
              )
            : widget.maxFontSize;

        return Text(
          widget.text,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}
