import 'package:flutter/material.dart';
import 'package:memolanes/common/component/liquid_glass_surface.dart';

/// Shared glass treatment for controls in the time-machine overlay.
class TimeMachineGlassSurface extends StatelessWidget {
  const TimeMachineGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding,
    this.shadowAlpha = 0.1,
  }) : assert(shadowAlpha >= 0 && shadowAlpha <= 1);

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: borderRadius,
      backgroundAlpha: 0.60,
      borderAlpha: 0.84,
      blurSigma: 24,
      reflectionAlpha: 0.12,
      shadowAlpha: shadowAlpha,
      shadowBlurRadius: 18,
      shadowSpreadRadius: 0,
      shadowOffset: const Offset(0, 6),
      padding: padding,
      child: child,
    );
  }
}
