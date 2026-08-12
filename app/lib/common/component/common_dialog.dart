import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/component/app_dialog.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DialogButton {
  DialogButton({
    required this.text,
    VoidCallback? onPressed,
    this.variant = AppButtonVariant.primary,
  }) : onPressed = onPressed ?? (() {});

  final String text;
  final VoidCallback onPressed;
  final AppButtonVariant variant;
}

class CommonDialog extends StatelessWidget {
  CommonDialog({
    super.key,
    required this.title,
    required this.content,
    List<DialogButton>? buttons,
    bool? showCancel,
    this.customCancelButton,
    this.markdown = false,
  }) : buttons = buttons ?? [];

  final String title;
  final String content;
  final bool markdown;
  final List<DialogButton> buttons;
  final DialogButton? customCancelButton;

  @override
  Widget build(BuildContext context) {
    final messageBody = switch (markdown) {
      false => ListBody(
          children: const LineSplitter()
              .convert(content)
              .map(
                (line) => Text(
                  line,
                  style: const TextStyle(
                    color: StyleConstants.inkColor,
                    fontSize: 14,
                    height: 1.42,
                  ),
                ),
              )
              .toList(),
        ),
      true => MarkdownBody(
          data: content,
          onTapLink: (text, href, title) async {
            if (href == null) return;
            if (!await launchUrlString(
              href,
              mode: LaunchMode.externalApplication,
            )) {
              throw Exception('Could not launch url: $href');
            }
          },
        ),
    };

    return PointerInterceptor(
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppDialogCard(
            title: title,
            maxHeightFactor: 0.78,
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            actions: buttons.isEmpty
                ? null
                : AppDialogActions(
                    children: [
                      for (final button in buttons)
                        AppButton(
                          label: button.text,
                          variant: button.variant,
                          onPressed: () {
                            AppHaptics.selection();
                            button.onPressed();
                          },
                        ),
                    ],
                  ),
            child: messageBody,
          ),
        ),
      ),
    );
  }
}
