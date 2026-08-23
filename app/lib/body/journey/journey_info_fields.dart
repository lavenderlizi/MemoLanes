import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/component/app_option_tile.dart';
import 'package:memolanes/common/component/basic_bottom_sheet.dart';
import 'package:memolanes/common/component/tiles/label_tile.dart';
import 'package:memolanes/common/component/tiles/label_tile_content.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/import.dart' as import_api;
import 'package:memolanes/src/rust/journey_header.dart';

String importPreprocessorLabel(
  BuildContext context,
  import_api.ImportPreprocessor value,
) =>
    switch (value) {
      import_api.ImportPreprocessor.none =>
        context.tr('import.preprocessor.none'),
      import_api.ImportPreprocessor.generic =>
        context.tr('import.preprocessor.generic'),
      import_api.ImportPreprocessor.flightTrack =>
        context.tr('import.preprocessor.flight_track'),
      import_api.ImportPreprocessor.spare =>
        context.tr('import.preprocessor.spare'),
    };

String journeyKindLabel(BuildContext context, JourneyKind value) =>
    switch (value) {
      JourneyKind.defaultKind => context.tr('journey_kind.default'),
      JourneyKind.flight => context.tr('journey_kind.flight'),
    };

class ImportPreprocessorTile extends StatelessWidget {
  const ImportPreprocessorTile({
    super.key,
    required this.value,
    required this.onSelected,
    this.onInfoTap,
  });

  final import_api.ImportPreprocessor value;
  final ValueChanged<import_api.ImportPreprocessor> onSelected;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    return LabelTile(
      label: context.tr('import.preprocessor.label'),
      infoLabelOnTap: onInfoTap,
      position: LabelTilePosition.single,
      trailing: LabelTileContent(
        content: importPreprocessorLabel(context, value),
        showArrow: true,
      ),
      onTap: () => _showOptionPicker(
        context,
        values: import_api.ImportPreprocessor.values,
        selectedValue: value,
        labelOf: (item) => importPreprocessorLabel(context, item),
        onSelected: onSelected,
      ),
    );
  }
}

class JourneyKindTile extends StatelessWidget {
  const JourneyKindTile({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final JourneyKind value;
  final ValueChanged<JourneyKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return LabelTile(
      label: context.tr('journey.journey_kind'),
      position: LabelTilePosition.single,
      trailing: LabelTileContent(
        content: journeyKindLabel(context, value),
        showArrow: true,
      ),
      onTap: () => _showOptionPicker(
        context,
        values: JourneyKind.values,
        selectedValue: value,
        labelOf: (item) => journeyKindLabel(context, item),
        onSelected: onSelected,
      ),
    );
  }
}

class JourneyNoteTile extends StatelessWidget {
  const JourneyNoteTile({
    super.key,
    required this.controller,
    this.maxHeight = 150,
    this.maxLines = 5,
    this.widthFactor = 0.6,
  });

  final TextEditingController controller;
  final double maxHeight;
  final int maxLines;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return LabelTile(
      label: context.tr('journey.note'),
      position: LabelTilePosition.single,
      maxHeight: maxHeight,
      trailing: SizedBox(
        width: MediaQuery.sizeOf(context).width * widthFactor,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: maxLines,
          minLines: 1,
          style: AppTypography.body.copyWith(
            color: StyleConstants.inkColor,
          ),
          decoration: InputDecoration.collapsed(
            border: InputBorder.none,
            hintText: context.tr('common.please_enter'),
            hintStyle: AppTypography.body.copyWith(
              color: StyleConstants.mutedInkColor,
            ),
          ),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

void _showOptionPicker<T>(
  BuildContext context, {
  required List<T> values,
  required T selectedValue,
  required String Function(T value) labelOf,
  required ValueChanged<T> onSelected,
}) {
  showBasicCard(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          AppOptionTile(
            title: labelOf(values[i]),
            selected: values[i] == selectedValue,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              onSelected(values[i]);
            },
          ),
        ],
      ],
    ),
  );
}
