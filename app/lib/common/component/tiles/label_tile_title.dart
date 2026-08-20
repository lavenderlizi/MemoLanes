import 'package:flutter/material.dart';
import 'package:memolanes/constants/style_constants.dart';

class LabelTileTitle extends StatelessWidget {
  const LabelTileTitle({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          maxHeight: 54.0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: StyleConstants.deepGreen,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
