import 'package:flutter/material.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/component/app_dialog.dart';
import 'package:memolanes/constants/style_constants.dart';

Future<T?> showBasicBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  Widget? actions,
  Widget? leading,
  bool showTitle = true,
  double? maxHeightFactor,
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
  Color? barrierColor,
  Color backgroundColor = StyleConstants.canvasColor,
}) {
  return showAppDialog<T>(
    context,
    barrierColor: barrierColor,
    maxWidth: 440,
    child: AppDialogCard(
      title: title,
      leading: leading,
      showHeader: showTitle && title != null,
      maxHeightFactor: maxHeightFactor ?? 0.78,
      contentPadding: contentPadding,
      backgroundColor: backgroundColor,
      actions: actions,
      child: child,
    ),
  );
}

void showBasicCard(
  BuildContext context, {
  required Widget child,
  String? title,
  IconData? icon,
}) {
  showBasicBottomSheet<void>(
    context,
    title: title,
    leading: icon == null ? null : AppDialogHeaderIcon(icon: icon),
    showTitle: title != null,
    contentPadding: EdgeInsets.fromLTRB(12, title == null ? 4 : 12, 12, 12),
    child: child,
  );
}

Future<T?> showBasicCardWithResult<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? primaryButtonText,
  VoidCallback? onPrimaryPressed,
  bool showLeading = true,
}) {
  return showBasicBottomSheet<T>(
    context,
    title: title,
    showTitle: true,
    maxHeightFactor: 0.75,
    leading: showLeading
        ? IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: StyleConstants.deepGreen,
            ),
            onPressed: () => Navigator.of(context).pop(),
          )
        : null,
    actions: primaryButtonText != null && onPrimaryPressed != null
        ? AppButton(
            label: primaryButtonText,
            onPressed: onPrimaryPressed,
            expand: true,
          )
        : null,
    child: child,
  );
}
