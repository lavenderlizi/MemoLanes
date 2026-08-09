import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/gps_manager.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

class RecordingButtons extends StatefulWidget {
  const RecordingButtons({super.key});

  @override
  State<RecordingButtons> createState() => _RecordingButtonsState();
}

class _RecordingButtonsState extends State<RecordingButtons> {
  Future<void> _showEndJourneyDialog() async {
    AppHaptics.warning();
    final gpsManager = context.read<GpsManager>();
    final shouldEndJourney = await showCommonDialog(
      context,
      context.tr('home.end_journey_message'),
      hasCancel: true,
      title: context.tr('home.end_journey_title'),
      confirmButtonText: context.tr('common.end'),
      confirmGroundColor: const Color(0xFFC84A45),
      confirmTextColor: Colors.white,
    );

    if (shouldEndJourney) {
      gpsManager.changeRecordingState(GpsRecordingStatus.none);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsManager = context.watch<GpsManager>();
    final status = gpsManager.recordingStatus;

    return PointerInterceptor(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: switch (status) {
            GpsRecordingStatus.none => _StartJourneyButton(
                key: const ValueKey('record-start'),
                onPressed: () {
                  AppHaptics.heavy();
                  gpsManager.changeRecordingState(
                    GpsRecordingStatus.recording,
                  );
                },
              ),
            GpsRecordingStatus.recording => _ActiveJourneyControls(
                key: const ValueKey('record-active'),
                isPaused: false,
                onPrimaryPressed: () {
                  AppHaptics.medium();
                  gpsManager.changeRecordingState(GpsRecordingStatus.paused);
                },
                onEndPressed: _showEndJourneyDialog,
              ),
            GpsRecordingStatus.paused => _ActiveJourneyControls(
                key: const ValueKey('record-paused'),
                isPaused: true,
                onPrimaryPressed: () {
                  AppHaptics.medium();
                  gpsManager.changeRecordingState(
                    GpsRecordingStatus.recording,
                  );
                },
                onEndPressed: _showEndJourneyDialog,
              ),
          },
        ),
      ),
    );
  }
}

class _StartJourneyButton extends StatelessWidget {
  const _StartJourneyButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: StyleConstants.primaryGreen,
          foregroundColor: StyleConstants.inkColor,
          elevation: 8,
          shadowColor: StyleConstants.deepGreen.withValues(alpha: 0.22),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: StyleConstants.journeyYellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                color: StyleConstants.inkColor,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.tr('home.start_new_journey'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJourneyControls extends StatelessWidget {
  const _ActiveJourneyControls({
    super.key,
    required this.isPaused,
    required this.onPrimaryPressed,
    required this.onEndPressed,
  });

  final bool isPaused;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onEndPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 142,
            height: 46,
            child: FilledButton.icon(
              onPressed: onPrimaryPressed,
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 21,
              ),
              label: Text(
                context.tr(isPaused ? 'home.resume' : 'home.pause'),
                maxLines: 1,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isPaused
                    ? StyleConstants.primaryGreen
                    : StyleConstants.journeyYellow,
                foregroundColor: StyleConstants.inkColor,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: onEndPressed,
            tooltip: context.tr('common.end'),
            style: IconButton.styleFrom(
              backgroundColor: StyleConstants.softYellow,
              foregroundColor: StyleConstants.inkColor,
              fixedSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.stop_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
