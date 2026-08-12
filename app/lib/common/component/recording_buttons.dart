import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/liquid_glass_surface.dart';
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
      width: 164,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: StyleConstants.primaryGreen.withValues(alpha: 0.78),
          foregroundColor: StyleConstants.inkColor,
          elevation: 8,
          shadowColor: StyleConstants.deepGreen.withValues(alpha: 0.22),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ),
        child: Text(
          context.tr('home.start_new_journey'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
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
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(23),
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        height: 42,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 112,
              height: 42,
              child: FilledButton.icon(
                onPressed: onPrimaryPressed,
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                ),
                label: Text(
                  context.tr(isPaused ? 'home.resume' : 'home.pause'),
                  maxLines: 1,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isPaused
                      ? StyleConstants.primaryGreen.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.18),
                  foregroundColor: isPaused
                      ? StyleConstants.deepGreen
                      : StyleConstants.mutedInkColor,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.56),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: onEndPressed,
              tooltip: context.tr('common.end'),
              style: IconButton.styleFrom(
                backgroundColor:
                    StyleConstants.softYellow.withValues(alpha: 0.58),
                foregroundColor: StyleConstants.inkColor,
                fixedSize: const Size(42, 42),
              ),
              icon: const Icon(Icons.stop_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
