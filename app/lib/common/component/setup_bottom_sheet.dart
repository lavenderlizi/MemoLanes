import 'package:flutter/material.dart';
import 'package:memolanes/constants/style_constants.dart';

Future<T?> showSetupCard<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class SetupBottomSheet extends StatelessWidget {
  const SetupBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading,
    this.showTitle = true,
    this.maxHeightFactor = 0.75,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;
  final bool showTitle;
  final double maxHeightFactor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      decoration: BoxDecoration(
        color: StyleConstants.canvasColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StyleConstants.lineColor),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          if (showTitle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
              child: Row(
                children: [
                  leading ?? const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: StyleConstants.inkColor,
                        fontSize: 17,
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
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SetupTile extends StatelessWidget {
  const SetupTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleTrailing,
    this.extraContent,
    this.onTap,
    this.selected = false,
    this.minHeight,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? titleTrailing;
  final Widget? extraContent;
  final VoidCallback? onTap;
  final bool selected;
  final double? minHeight;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints:
          minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
      padding: contentPadding,
      decoration: BoxDecoration(
        color: selected
            ? StyleConstants.softGreen.withValues(alpha: 0.82)
            : StyleConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              selected ? StyleConstants.primaryGreen : StyleConstants.lineColor,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? StyleConstants.primaryGreen.withValues(alpha: 0.32)
                  : StyleConstants.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: StyleConstants.deepGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: StyleConstants.inkColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 6),
                      titleTrailing!,
                    ],
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        color: StyleConstants.mutedInkColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (extraContent != null) extraContent!,
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: tile,
      ),
    );
  }
}
