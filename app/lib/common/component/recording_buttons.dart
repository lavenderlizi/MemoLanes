import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/liquid_glass_surface.dart';
import 'package:memolanes/common/gps_manager.dart';
import 'package:memolanes/common/utils.dart';
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
      child: AppButton(
        label: context.tr('home.start_new_journey'),
        onPressed: onPressed,
        size: AppButtonSize.large,
        backgroundAlpha: 0.78,
        expand: true,
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
              child: AppButton(
                label: context.tr(isPaused ? 'home.resume' : 'home.pause'),
                onPressed: onPrimaryPressed,
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                variant: isPaused
                    ? AppButtonVariant.tonal
                    : AppButtonVariant.secondary,
                size: AppButtonSize.compact,
                backgroundAlpha: isPaused ? 0.56 : 0.5,
                expand: true,
              ),
            ),
            const SizedBox(width: 6),
            AppIconButton(
              onPressed: onEndPressed,
              tooltip: context.tr('common.end'),
              icon: Icons.stop_rounded,
              variant: AppButtonVariant.danger,
            ),
          ],
        ),
      ),
    );
  }
}
