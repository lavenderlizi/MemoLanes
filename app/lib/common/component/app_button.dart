import 'package:flutter/material.dart';
import 'package:memolanes/constants/style_constants.dart';

enum AppButtonVariant { primary, secondary, tonal, danger }

enum AppButtonSize { compact, regular, large }

extension on AppButtonVariant {
  Color get backgroundColor => switch (this) {
        AppButtonVariant.primary => StyleConstants.primaryGreen,
        AppButtonVariant.secondary => StyleConstants.surfaceColor,
        AppButtonVariant.tonal => StyleConstants.softGreen,
        AppButtonVariant.danger => const Color(0xFFC7485D),
      };

  Color get foregroundColor => switch (this) {
        AppButtonVariant.danger => Colors.white,
        _ => StyleConstants.deepGreen,
      };

  BorderSide? get side => switch (this) {
        AppButtonVariant.secondary =>
          const BorderSide(color: StyleConstants.lineColor),
        _ => null,
      };
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.loading = false,
    this.backgroundAlpha = 1,
    this.borderRadius,
    this.fontSize,
  })  : assert(backgroundAlpha >= 0 && backgroundAlpha <= 1),
        assert(borderRadius == null || borderRadius >= 0),
        assert(fontSize == null || fontSize > 0);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool loading;
  final double backgroundAlpha;
  final double? borderRadius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.compact => 38.0,
      AppButtonSize.regular => 44.0,
      AppButtonSize.large => 52.0,
    };
    final radius = borderRadius ??
        switch (size) {
          AppButtonSize.compact => 13.0,
          AppButtonSize.regular => 14.0,
          AppButtonSize.large => 24.0,
        };
    final resolvedFontSize = fontSize ??
        switch (size) {
          AppButtonSize.compact => 12.0,
          AppButtonSize.regular => 14.0,
          AppButtonSize.large => 16.0,
        };
    final horizontalPadding = switch (size) {
      AppButtonSize.compact => 10.0,
      AppButtonSize.regular => 16.0,
      AppButtonSize.large => 18.0,
    };
    final iconSize = switch (size) {
      AppButtonSize.compact => 16.0,
      AppButtonSize.regular => 18.0,
      AppButtonSize.large => 20.0,
    };
    final style = FilledButton.styleFrom(
      elevation: 0,
      backgroundColor:
          variant.backgroundColor.withValues(alpha: backgroundAlpha),
      foregroundColor: variant.foregroundColor,
      disabledBackgroundColor: StyleConstants.lineColor,
      disabledForegroundColor:
          StyleConstants.mutedInkColor.withValues(alpha: 0.62),
      side: variant.side,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      textStyle: TextStyle(
        fontSize: resolvedFontSize,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    final iconWidget = loading
        ? SizedBox.square(
            dimension: size == AppButtonSize.compact ? 15 : 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant.foregroundColor,
            ),
          )
        : icon == null
            ? null
            : Icon(
                icon,
                size: iconSize,
              );
    final effectiveOnPressed = loading ? null : onPressed;
    final button = iconWidget == null
        ? FilledButton(
            onPressed: effectiveOnPressed,
            style: style,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: style,
            icon: iconWidget,
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: button,
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AppButtonVariant.tonal,
    this.size = 42,
  }) : assert(size > 0);

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppButtonVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: variant.backgroundColor,
        foregroundColor: variant.foregroundColor,
        disabledBackgroundColor: StyleConstants.lineColor,
        fixedSize: Size.square(size),
        side: variant.side,
      ),
      icon: Icon(icon, size: size * 0.48),
    );
  }
}
