import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:memolanes/common/component/bottom_nav_bar.dart';

class StyleConstants {
  StyleConstants._();

  // Foundations
  static const Color canvasColor = Color(0xFFFAFBF5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color inkColor = Color(0xFF182016);
  static const Color mutedInkColor = Color(0xFF6C7567);
  static const Color subtleInkColor = Color(0xFF9CA59F);
  static const Color lineColor = Color(0xFFE7EBD9);
  static const Color strongLineColor = Color(0xFFC8D1C1);

  // Brand and selection. The lime is deliberately reserved for compact
  // emphasis and primary actions instead of large decorative surfaces.
  static const Color primaryGreen = Color(0xFFB8EA72);
  static const Color deepGreen = Color(0xFF2E693D);
  static const Color softGreen = Color(0xFFECF9D9);
  static const Color journeyYellow = Color(0xFFFFD72E);
  static const Color deepYellow = Color(0xFF8B6600);
  static const Color softYellow = Color(0xFFFFF5BD);

  static const Color primaryActionColor = primaryGreen;
  static const Color onPrimaryActionColor = deepGreen;
  static const Color selectedSurfaceColor = softGreen;

  // Feedback colors. These are quieter than Flutter's stock red and orange,
  // and keep status meaning separate from brand accents.
  static const Color warningColor = journeyYellow;
  static const Color warningInkColor = deepYellow;
  static const Color warningSurfaceColor = softYellow;
  static const Color dangerColor = Color(0xFFC7485D);
  static const Color dangerInkColor = Color(0xFF8F2F42);
  static const Color dangerSurfaceColor = Color(0xFFFBEAEC);
  static const Color onDangerColor = surfaceColor;
  static const Color recordingColor = Color(0xFFD95357);
  static const Color statusExcellentColor = deepGreen;
  static const Color statusGoodColor = deepYellow;
  static const Color statusFairColor = Color(0xFFB56C32);
  static const Color statusPoorColor = dangerColor;

  // Achievement colors remain gold so the category keeps its own identity,
  // while using one shared hue instead of several unrelated yellows.
  static const Color achievementGoldColor = Color(0xFFB88722);
  static const Color achievementGoldSurfaceStart = Color(0xFFFFF7D9);
  static const Color achievementGoldSurfaceEnd = Color(0xFFF1E5B5);
  static const Color profileAccentStartColor = deepGreen;
  static const Color profileAccentEndColor = deepYellow;

  // Active switches use the soft green surface tone used across settings.
  // Keeping these colors role-specific lets settings controls be tuned without
  // changing buttons, GPS status indicators, or other selected states.
  static const Color switchActiveTrackColor = softGreen;
  static const Color switchActiveThumbColor = deepGreen;
  static const Color switchInactiveTrackColor = Color(0xFFDDE2DC);
  static const Color switchInactiveThumbColor = subtleInkColor;
  static const Color switchTrackOutlineColor = strongLineColor;
  static const double switchActiveThumbSize = 18;
  static const double switchInactiveThumbSize = 16;
  static const double switchTrackOutlineWidth = 1;

  // navBar
  // Visual bottom inset for the floating nav bar on gesture/home-indicator
  // devices. This intentionally differs from the raw safe-area value so iOS
  // and Android look closer while still clearing bottom rounded corners.
  static const double navBarGestureBottomInset = 32;

  // Gap above a non-gesture system navigation area, such as Android 3-button
  // navigation.
  static const double navBarSystemAreaGap = 5;

  // Fallback inset for screens without a reported bottom system area.
  static const double navBarMinimumBottomInset = 32;

  // Vertical space occupied by the nav bar and its fixed bottom inset.
  // Scrollable pages use this to keep content clear of the floating nav bar.
  static const double navBarSafeArea =
      BottomNavBar.height + navBarMinimumBottomInset;

  // Gap between the nav bar and primary map controls such as recording buttons
  // and the time-machine ruler.
  static const double mapPrimaryControlNavBarSpacing = 14;

  // Bottom inset shared by primary map controls so they align across map modes.
  static const double mapPrimaryControlBottomInset =
      navBarSafeArea + mapPrimaryControlNavBarSpacing;

  static double navBarBottomInset(BuildContext context) {
    final bottomGestureInset = MediaQuery.systemGestureInsetsOf(context).bottom;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;

    return switch ((
      bottomGestureInset,
      bottomSafeArea,
      defaultTargetPlatform,
    )) {
      (> 0, _, _) => bottomGestureInset + navBarGestureBottomInset,
      (_, > 0, TargetPlatform.iOS) => navBarGestureBottomInset,
      (_, > 0, _) => bottomSafeArea + navBarSystemAreaGap,
      _ => navBarMinimumBottomInset,
    };
  }

  static double navBarSafeAreaForContext(BuildContext context) =>
      BottomNavBar.height + navBarBottomInset(context);

  static double mapPrimaryControlBottomInsetForContext(BuildContext context) =>
      navBarSafeAreaForContext(context) + mapPrimaryControlNavBarSpacing;

  // Overlays
  static const Color loadingMaskColor = Color(0x59182016);
  static const double overlayFloatingRadius = 16.0;

  // Shared elevation for glass buttons and cards displayed over the map.
  // A modest, compact shadow keeps light glass distinct from light fog
  // without making the controls look like solid Material cards.
  static const double mapOverlayShadowAlpha = 0.18;
  static const double mapOverlayShadowBlurRadius = 26;
  static const double mapOverlayShadowSpreadRadius = -3;
  static const Offset mapOverlayShadowOffset = Offset(0, 8);

  // Calm, readable glass used by the time-machine ruler and other secondary
  // map controls that should remain visible without looking like solid cards.
  static const double timelineGlassBackgroundAlpha = 0.60;
  static const double timelineGlassBorderAlpha = 0.84;
  static const double timelineGlassBlurSigma = 24;
  static const double timelineGlassReflectionAlpha = 0.12;
}
