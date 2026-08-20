/// Visual parameters for the unexplored-area overlay drawn above the base map.
///
/// Fog styling is intentionally independent from [MapStyle]. This allows the
/// app to switch light and dark fog appearances without coupling them to a
/// particular tile provider.
class MapFogStyle {
  const MapFogStyle({
    required this.colorHex,
    required this.opacity,
  });

  /// A CSS-compatible six-digit RGB color.
  final String colorHex;

  /// Overlay opacity in the inclusive range 0–1.
  final double opacity;

  /// Low-chroma charcoal fog designed for the current light application UI.
  static const dark = MapFogStyle(
    colorHex: '#1E2528',
    opacity: 0.40,
  );
}
