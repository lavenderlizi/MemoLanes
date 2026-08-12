import 'package:easy_localization/easy_localization.dart';
import 'package:memolanes/src/rust/api/utils.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/component/common_dialog.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/body/settings/mldx_import_page.dart';
import 'package:memolanes/common/loading_manager.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/import.dart';
import 'package:memolanes/common/log.dart';

final _naiveDateFormat = DateFormat('yyyy-MM-dd');

NaiveDate dateTimeToNaiveDate(DateTime dateTime) =>
    naiveDateOfString(str: _naiveDateFormat.format(dateTime));

DateTime naiveDateToDateTime(NaiveDate naiveDate) =>
    _naiveDateFormat.parse(naiveDateToString(date: naiveDate));

bool popCurrentRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted) return false;

  final route = ModalRoute.of(context);
  if (route?.isCurrent != true) return false;

  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return false;

  navigator.pop<T>(result);
  return true;
}

Future<bool> showCommonDialog(BuildContext context, String message,
    {bool hasCancel = false,
    String? title,
    String? confirmButtonText,
    String? cancelButtonText,
    Color? confirmGroundColor,
    Color confirmTextColor = Colors.black,
    bool markdown = false}) async {
  final resolvedConfirmButtonText =
      confirmButtonText ?? context.tr("common.ok");
  final resolvedCancelButtonText =
      cancelButtonText ?? context.tr("common.cancel");
  final dialogTitle = title ?? context.tr("common.info");
  final usesDefaultConfirmColor = confirmGroundColor == null;
  final List<DialogButton> allButtons = [
    if (hasCancel)
      DialogButton(
        text: resolvedCancelButtonText,
        variant: AppButtonVariant.secondary,
        onPressed: () {
          Navigator.of(context).pop(false);
        },
      ),
    DialogButton(
      text: resolvedConfirmButtonText,
      variant: usesDefaultConfirmColor
          ? AppButtonVariant.primary
          : AppButtonVariant.danger,
      onPressed: () {
        Navigator.of(context).pop(true);
      },
    ),
  ];

  var result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: StyleConstants.inkColor.withValues(alpha: 0.22),
    builder: (BuildContext context) {
      return CommonDialog(
        title: dialogTitle,
        content: message,
        showCancel: hasCancel,
        buttons: allButtons,
        markdown: markdown,
      );
    },
  );
  return result ?? false;
}

Future<T> showLoadingDialog<T>({
  required Future<T> asyncTask,
}) async {
  final result = await GlobalLoadingManager.instance.runWithLoading<T>(
    () => asyncTask,
  );
  return result;
}

Future<void> importMldx(BuildContext context, String path) async {
  try {
    final (mldxFile, preview) = await showLoadingDialog(
      asyncTask: (() async {
        final mldxFile = await OpaqueMldxReader.open(mldxFilePath: path);
        final preview = await mldxFile.analyze();
        return (mldxFile, preview);
      })(),
    );
    if (!context.mounted) return;
    final unchangedCount = preview
        .where((j) => j.$2 == MldxJourneyImportAnalyzeResult.unchanged)
        .length;
    final importableCount = preview
        .where((j) => j.$2 != MldxJourneyImportAnalyzeResult.unchanged)
        .length;

    // If everything is skipped, end the flow here.
    if (importableCount == 0 && unchangedCount > 0) {
      await showCommonDialog(
        context,
        context.tr(
          'import.mldx_preview.all_skipped',
          args: ['$unchangedCount'],
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MldxImportPage(
          journeys: preview,
          mldxReader: mldxFile,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      await showCommonDialog(context, context.tr("import.parsing_failed"));
      log.error("[import_data] Data parsing failed $error");
    }
  }
}
