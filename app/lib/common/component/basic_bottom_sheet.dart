import 'package:flutter/material.dart';
import 'package:memolanes/common/component/cards/line_painter.dart';
import 'package:memolanes/constants/style_constants.dart';

class BasicBottomSheet extends StatelessWidget {
  const BasicBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.leading,
    this.showHandle = false,
    this.showTitle = true,
    this.maxHeightFactor,
    this.contentPadding = EdgeInsets.zero,
    this.backgroundColor = StyleConstants.canvasColor,
  });

  final Widget child;
  final String? title;
  final Widget? actions;
  final Widget? leading;
  final bool showHandle;
  final bool showTitle;
  final double? maxHeightFactor;
  final EdgeInsetsGeometry contentPadding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: maxHeightFactor == null
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFactor!,
            ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: CustomPaint(
                  size: const Size(40.0, 4.0),
                  painter: LinePainter(
                    color: const Color(0xFFB5B5B5),
                  ),
                ),
              ),
            )
          else
            SizedBox(height: showTitle && title != null ? 12 : 8),
          if (showTitle && title != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  leading ?? const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: StyleConstants.inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: contentPadding,
              child: child,
            ),
          ),
          if (actions != null) actions!,
        ],
      ),
    );

    return content;
  }
}

Future<T?> showBasicBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  Widget? actions,
  Widget? leading,
  bool showHandle = false,
  bool showTitle = true,
  double? maxHeightFactor,
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
  Color? barrierColor,
  Color backgroundColor = StyleConstants.canvasColor,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: barrierColor,
    barrierDismissible: true,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final heightFactor = maxHeightFactor ?? 0.78;
      return Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: mediaQuery.size.height * heightFactor,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: StyleConstants.inkColor.withValues(alpha: 0.18),
                  blurRadius: 32,
                  spreadRadius: -8,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: BasicBottomSheet(
              title: title,
              actions: actions,
              leading: leading,
              showHandle: showHandle,
              showTitle: showTitle,
              contentPadding: contentPadding,
              backgroundColor: backgroundColor,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

void showBasicCard(
  BuildContext context, {
  required Widget child,
  bool showHandle = false,
}) {
  showBasicBottomSheet<void>(
    context,
    showHandle: showHandle,
    showTitle: false,
    child: child,
  );
}

Future<T?> showBasicCardWithResult<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? primaryButtonText,
  VoidCallback? onPrimaryPressed,
  bool showHandle = false,
  bool showLeading = true,
}) {
  return showBasicBottomSheet<T>(
    context,
    title: title,
    showHandle: showHandle,
    showTitle: showLeading,
    maxHeightFactor: 0.75,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios,
        color: StyleConstants.inkColor,
      ),
      onPressed: () => Navigator.of(context).pop(),
    ),
    actions: primaryButtonText != null && onPrimaryPressed != null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: StyleConstants.primaryGreen,
                  foregroundColor: StyleConstants.inkColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(primaryButtonText),
              ),
            ),
          )
        : null,
    child: child,
  );
}
