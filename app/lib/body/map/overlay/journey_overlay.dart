import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/journey_body.dart';
import 'package:memolanes/body/journey/journey_info_page.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/utils/nav_helper.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Journeys keeps the current map visible without Record mode's three map
/// controls. Its picker is an in-page floating card, so the app navigation bar
/// remains visible and unobstructed below it.
class JourneyOverlay extends StatefulWidget {
  const JourneyOverlay({super.key});

  @override
  State<JourneyOverlay> createState() => _JourneyOverlayState();
}

class _JourneyOverlayState extends State<JourneyOverlay> {
  bool _pickerOpen = false;

  void _togglePicker() {
    AppHaptics.light();
    setState(() => _pickerOpen = !_pickerOpen);
  }

  Future<bool?> _openJourneyDetails(JourneyHeader journey) {
    // Keep this overlay (and the open picker) mounted underneath the details
    // route. Popping JourneyInfoPage therefore reveals the picker again.
    return navigatorPush<bool>(
      context,
      page: JourneyInfoPage(journeyHeader: journey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;
    final bottom =
        StyleConstants.mapPrimaryControlBottomInsetForContext(context);
    final availableHeight = math.max(
      260.0,
      mediaQuery.size.height - bottom - viewPadding.top - 12,
    );
    final preferredHeight =
        (mediaQuery.size.height * 0.62).clamp(390.0, 530.0).toDouble();
    final pickerHeight = math.min(preferredHeight, availableHeight);

    return Stack(
      children: [
        Positioned(
          left: viewPadding.left + 16,
          right: viewPadding.right + 16,
          bottom: bottom,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            reverseDuration: const Duration(milliseconds: 210),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _pickerOpen
                ? Align(
                    key: const ValueKey('journey-picker'),
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: math.min(mediaQuery.size.width - 32, 480.0),
                      height: pickerHeight,
                      child: PointerInterceptor(
                        child: _JourneyPickerCard(
                          onClose: _togglePicker,
                          onJourneySelected: _openJourneyDetails,
                        ),
                      ),
                    ),
                  )
                : Align(
                    key: const ValueKey('journey-picker-button'),
                    alignment: Alignment.bottomCenter,
                    child: PointerInterceptor(
                      child: _JourneyPickerButton(onPressed: _togglePicker),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _JourneyPickerCard extends StatelessWidget {
  const _JourneyPickerCard({
    required this.onClose,
    required this.onJourneySelected,
  });

  final VoidCallback onClose;
  final Future<bool?> Function(JourneyHeader journey) onJourneySelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Material(
            color: Colors.white.withValues(alpha: 0.9),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 9, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: StyleConstants.softGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          size: 17,
                          color: StyleConstants.deepGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('journey.picker_title'),
                          style: const TextStyle(
                            color: StyleConstants.deepGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: StyleConstants.mutedInkColor,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: StyleConstants.lineColor.withValues(alpha: 0.9),
                ),
                Expanded(
                  child: JourneyBody(
                    compactPicker: true,
                    onJourneySelected: onJourneySelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyPickerButton extends StatelessWidget {
  const _JourneyPickerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Material(
            color: Colors.white.withValues(alpha: 0.74),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: StyleConstants.softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        size: 17,
                        color: StyleConstants.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('journey.choose_journey'),
                      style: const TextStyle(
                        color: StyleConstants.deepGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 19,
                      color: StyleConstants.deepGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
