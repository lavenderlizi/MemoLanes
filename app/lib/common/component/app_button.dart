import 'package:flutter/material.dart';
import 'package:memolanes/constants/style_constants.dart';

enum AppButtonVariant { primary, secondary, tonal, danger }

enum AppButtonSize { compact, regular, large }

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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool loading;
  final double backgroundAlpha;

  Color get _backgroundColor => switch (variant) {
        AppButtonVariant.primary => StyleConstants.primaryGreen,
        AppButtonVariant.secondary => StyleConstants.surfaceColor,
        AppButtonVariant.tonal => StyleConstants.softGreen,
        AppButtonVariant.danger => const Color(0xFFC7485D),
      };

  Color get _foregroundColor => switch (variant) {
        AppButtonVariant.danger => Colors.white,
        _ => StyleConstants.deepGreen,
      };

  BorderSide? get _side => switch (variant) {
        AppButtonVariant.secondary =>
          const BorderSide(color: StyleConstants.lineColor),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.compact => 38.0,
      AppButtonSize.regular => 44.0,
      AppButtonSize.large => 52.0,
    };
    final radius = switch (size) {
      AppButtonSize.compact => 13.0,
      AppButtonSize.regular => 14.0,
      AppButtonSize.large => 24.0,
    };
    final fontSize = switch (size) {
      AppButtonSize.compact => 12.0,
      AppButtonSize.regular => 14.0,
      AppButtonSize.large => 16.0,
    };
    final horizontalPadding = switch (size) {
      AppButtonSize.compact => 10.0,
      AppButtonSize.regular => 16.0,
      AppButtonSize.large => 18.0,
    };
    final style = FilledButton.styleFrom(
      elevation: 0,
      backgroundColor: _backgroundColor.withValues(alpha: backgroundAlpha),
      foregroundColor: _foregroundColor,
      disabledBackgroundColor: StyleConstants.lineColor,
      disabledForegroundColor:
          StyleConstants.mutedInkColor.withValues(alpha: 0.62),
      side: _side,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      textStyle: TextStyle(
        fontSize: fontSize,
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
              color: _foregroundColor,
            ),
          )
        : icon == null
            ? null
            : Icon(
                icon,
                size: size == AppButtonSize.compact
                    ? 16
                    : size == AppButtonSize.large
                        ? 20
                        : 18,
              );
    final button = iconWidget == null
        ? FilledButton(
            onPressed: onPressed,
            style: style,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
            label: Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppButtonVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => StyleConstants.primaryGreen,
      AppButtonVariant.secondary => StyleConstants.surfaceColor,
      AppButtonVariant.tonal => StyleConstants.softGreen,
      AppButtonVariant.danger => const Color(0xFFC7485D),
    };
    final foregroundColor = variant == AppButtonVariant.danger
        ? Colors.white
        : StyleConstants.deepGreen;

    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: StyleConstants.lineColor,
        fixedSize: Size.square(size),
        side: variant == AppButtonVariant.secondary
            ? const BorderSide(color: StyleConstants.lineColor)
            : null,
      ),
      icon: Icon(icon, size: size * 0.48),
    );
  }
}
