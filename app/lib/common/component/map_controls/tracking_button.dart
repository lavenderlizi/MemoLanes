import 'package:flutter/material.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/constants/style_constants.dart';

class TrackingButton extends StatelessWidget {
  final TrackingMode trackingMode;
  final VoidCallback onPressed;

  const TrackingButton({
    super.key,
    required this.trackingMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () {
          AppHaptics.selection();
          onPressed();
        },
        icon: Icon(
          trackingMode == TrackingMode.off
              ? Icons.near_me_disabled
              : Icons.near_me,
          color: trackingMode == TrackingMode.displayAndTracking
              ? StyleConstants.deepGreen
              : StyleConstants.mutedInkColor,
        ),
        tooltip: trackingMode == TrackingMode.off
            ? 'Enable location tracking'
            : 'Disable location tracking',
      ),
    );
  }
}
