import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memolanes/body/achievement/achievement_region_area_list_page.dart';
import 'package:memolanes/body/achievement/achievement_globe_summary.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/body/achievement/achievement_picker.dart';
import 'package:memolanes/body/achievement/achievement_region_strip.dart';
import 'package:memolanes/body/map/overlay/journey_overlay.dart';
import 'package:memolanes/body/achievement/shared/achievement_common.dart';
import 'package:memolanes/common/achievement_stats_store.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/gps_manager.dart';
import 'package:memolanes/common/log.dart';
import 'package:memolanes/common/region_preference.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/achievement/layer.dart';
import 'package:memolanes/src/rust/achievement/region.dart';
import 'package:memolanes/src/rust/api/achievement.dart' as achievement_api;
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/theme/app_colors.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

/// Find the shortest longitude interval, including countries across the date
/// line. Every polygon (including overseas islands) participates in the fit.
MapBounds? achievementGeometryBounds(Map<String, dynamic> geometry) {
  final longitudes = <double>[];
  var south = 90.0;
  var north = -90.0;
  void visit(dynamic coordinates) {
    if (coordinates is! List || coordinates.isEmpty) return;
    if (coordinates.first is num && coordinates.length >= 2) {
      final lng = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();
      if (!lng.isFinite || !lat.isFinite) return;
      longitudes.add((lng + 360) % 360);
      south = math.min(south, lat);
      north = math.max(north, lat);
    } else {
      for (final child in coordinates) {
        visit(child);
      }
    }
  }

  visit(geometry['coordinates']);
  if (longitudes.isEmpty) return null;
  longitudes.sort();
  var gap = -1.0;
  var start = 0;
  for (var i = 0; i < longitudes.length; i++) {
    final next = i + 1 < longitudes.length
        ? longitudes[i + 1]
        : longitudes.first + 360;
    if (next - longitudes[i] > gap) {
      gap = next - longitudes[i];
      start = (i + 1) % longitudes.length;
    }
  }
  final west = longitudes[start] > 180
      ? longitudes[start] - 360
      : longitudes[start];
  return MapBounds(
    west: west,
    east: west + 360 - gap,
    south: south,
    north: north,
  );
}

List<MapEntry<achievement_api.GeoEntityId, RegionEntity>>
exploredAchievementRegions(RegionDetail detail) {
  final regions = detail.children.entries
      .where((entry) => entry.value.visitedAreaM2 > BigInt.zero)
      .toList();
  regions.sort((a, b) {
    final areaOrder = b.value.visitedAreaM2.compareTo(a.value.visitedAreaM2);
    return areaOrder != 0 ? areaOrder : a.key.field0.compareTo(b.key.field0);
  });
  return regions;
}

class AchievementMapView extends StatefulWidget {
  const AchievementMapView({
    super.key,
    required this.topSafeArea,
    required this.bottomSafeArea,
    required this.cardBuilder,
  });

  final double topSafeArea;
  final double bottomSafeArea;
  final Widget Function(ValueChanged<AchievementCountryStats>) cardBuilder;

  @override
  State<AchievementMapView> createState() => _AchievementMapViewState();
}

class _AchievementMapViewState extends State<AchievementMapView> {
  api.MapRendererProxy? _renderer;
  bool _mapError = false;
  bool _expanded = false;
  bool _loadingCountry = false;
  AchievementCountryStats? _country;
  RegionDetail? _detail;
  Map<String, dynamic>? _geometries;
  MapBounds? _bounds;
  Map<String, dynamic>? _overlay;
  int? _selectedRegionId;
  int _selectionRequest = 0;
  int _cameraRevision = 0;
  int _rendererRequest = 0;
  StreamSubscription<void>? _finalized;
  late final String _worldviewId;

  @override
  void initState() {
    super.initState();
    _worldviewId = WorldviewManager.instance.currentWorldview.id;
    unawaited(_loadRenderer());
    _finalized = context.read<GpsManager>().journeyFinalized.listen((_) {
      unawaited(_loadRenderer());
      final country = _country;
      if (country != null) unawaited(_selectCountry(country));
    });
  }

  @override
  void dispose() {
    _finalized?.cancel();
    super.dispose();
  }

  Future<void> _loadRenderer() async {
    final request = ++_rendererRequest;
    try {
      final (renderer, _) = await api.getMapRendererProxyForJourneyDateRange(
        fromDateInclusive: DateTime(1),
        toDateInclusive: DateTime(9999, 12, 31),
        journeyKinds: JourneyKind.values.toSet(),
      );
      if (!mounted || request != _rendererRequest) return;
      setState(() {
        _renderer = renderer;
        _mapError = false;
      });
    } catch (error, stack) {
      log.error('Loading achievement map failed: $error', stack);
      if (mounted && request == _rendererRequest) {
        setState(() => _mapError = true);
      }
    }
  }

  Future<Map<String, dynamic>> _loadGeometry(int countryId) async {
    final source = await rootBundle.loadString(
      'assets/geo/map_geometry_${_worldviewId}_$countryId.json',
      cache: false,
    );
    return (await compute(jsonDecode, source)) as Map<String, dynamic>;
  }

  Future<void> _selectCountry(AchievementCountryStats country) async {
    final request = ++_selectionRequest;
    setState(() {
      _expanded = false;
      _loadingCountry = true;
    });
    try {
      // Start both reads together; only the most recent selection may publish.
      final geometryFuture =
          _country?.entityId == country.entityId && _geometries != null
          ? Future.value(_geometries!)
          : _loadGeometry(country.entityId.field0);
      final detailFuture = achievement_api.regionDetail(
        entityId: country.entityId,
        layer: AchievementLayer.default_,
      );
      final results = await Future.wait<Object?>([
        geometryFuture,
        detailFuture,
      ]);
      if (!mounted || request != _selectionRequest) return;
      final geometries = results[0] as Map<String, dynamic>;
      final detail = results[1] as RegionDetail?;
      final feature =
          geometries[country.entityId.field0.toString()]
              as Map<String, dynamic>?;
      if (detail == null || feature == null) {
        throw StateError('Missing country geometry');
      }
      final bounds = achievementGeometryBounds(
        feature['geometry'] as Map<String, dynamic>,
      );
      if (bounds == null) throw StateError('Empty country geometry');
      setState(() {
        _country = country;
        _detail = detail;
        _geometries = geometries;
        _bounds = bounds;
        _cameraRevision++;
        _loadingCountry = false;
        _overlay = _buildOverlay(detail, geometries);
        _selectedRegionId = null;
      });
    } catch (error, stack) {
      log.error('Loading achievement country failed: $error', stack);
      if (!mounted || request != _selectionRequest) return;
      setState(() => _loadingCountry = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('achievement.map.load_error')),
          action: SnackBarAction(
            label: context.tr('achievement.map.retry'),
            onPressed: () => _selectCountry(country),
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _buildOverlay(
    RegionDetail detail,
    Map<String, dynamic> geometries,
  ) {
    final features = <Map<String, dynamic>>[];
    // The country boundary also covers land without a named administrative unit.
    final countryGeometry = geometries[detail.entityId.field0.toString()];
    features.add({
      'type': 'Feature',
      'geometry': countryGeometry['geometry'],
      'properties': {'id': detail.entityId.field0},
    });
    for (final entry in detail.children.entries) {
      final shape = geometries[entry.key.field0.toString()];
      if (shape == null) continue;
      features.add({
        'type': 'Feature',
        'geometry': shape['geometry'],
        'properties': {
          'id': entry.key.field0,
          'visited': entry.value.visitedAreaM2 > BigInt.zero,
        },
      });
    }
    return {
      'features': {'type': 'FeatureCollection', 'features': features},
      'selectedId': null,
    };
  }

  void _showGlobe() {
    ++_selectionRequest;
    setState(() {
      _country = null;
      _detail = null;
      _bounds = null;
      _cameraRevision++;
      _overlay = null;
      _selectedRegionId = null;
      _loadingCountry = false;
      _expanded = false;
    });
  }

  void _showRanking() {
    final detail = _detail;
    if (detail == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AchievementRegionAreaListPage(
          title: detail.node.displayName(_worldviewId),
          emptyText: context.tr('achievement.region_list.region_empty'),
          showIcons: false,
          items: exploredAchievementRegions(detail)
              .map(
                (entry) => AchievementRegionAreaListItem(
                  name: entry.value.displayName(_worldviewId),
                  visitedKm2: entry.value.visitedAreaM2.toDouble() / 1000000,
                  totalKm2: entry.value.totalAreaM2.toDouble() / 1000000,
                  sortKey: entry.key.field0.toString(),
                  onTap: () {
                    Navigator.of(context).pop();
                    _focusRegion(entry.key.field0);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _focusRegion(int id) {
    final detail = _detail;
    if (detail == null ||
        !exploredAchievementRegions(detail)
            .any((entry) => entry.key.field0 == id)) {
      return;
    }
    final shape = _geometries?[id.toString()];
    final bounds = shape == null
        ? null
        : achievementGeometryBounds(shape['geometry'] as Map<String, dynamic>);
    setState(() {
      _expanded = false;
      _selectedRegionId = id;
      if (_overlay != null) _overlay = {..._overlay!, 'selectedId': id};
      if (bounds != null) {
        _bounds = bounds;
        _cameraRevision++;
      }
    });
  }

  void _focusCountry() {
    final country = _country;
    if (country == null) return;
    final shape = _geometries?[country.entityId.field0.toString()];
    if (shape == null) return;
    setState(() {
      _selectedRegionId = null;
      _expanded = false;
      _bounds = achievementGeometryBounds(
        shape['geometry'] as Map<String, dynamic>,
      );
      _cameraRevision++;
      if (_overlay != null) _overlay = {..._overlay!, 'selectedId': null};
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AchievementStatsStore>();
    final stats = store.stats;
    final renderer = _renderer;
    final country = _country;
    final regions = _detail == null
        ? <MapEntry<achievement_api.GeoEntityId, RegionEntity>>[]
        : exploredAchievementRegions(_detail!);
    final regionStripHeight = country == null
        ? 0.0
        : AchievementRegionStrip.heightForContext(context);
    final horizontalInset = math.max(
      MediaQuery.viewPaddingOf(context).left,
      MediaQuery.viewPaddingOf(context).right,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final top = widget.topSafeArea + 12;
        final bottom = StyleConstants.mapPrimaryControlBottomInsetForContext(
          context,
        );
        final cardHeight = JourneyOverlay.pickerHeightForContext(context);
        final padding = EdgeInsets.fromLTRB(
          horizontalInset + 24,
          top + (country == null ? 144 : 56),
          horizontalInset + 24,
          bottom + 64 + regionStripHeight,
        );
        final globeDiameter = math.max(
          80.0,
          math.min(
            constraints.maxWidth - 56,
            constraints.maxHeight - padding.top - padding.bottom,
          ),
        );
        final globeView = (
          lng: 105.0,
          lat: 0.0,
          zoom: math.log(globeDiameter * math.pi / 512) / math.ln2,
        );
        return Stack(
          children: [
            if (renderer != null)
              BaseMapWebview(
                mapRendererProxy: renderer,
                initialMapView: globeView,
                flyToView: country == null ? globeView : null,
                flyToBounds: _bounds,
                cameraRevision: _cameraRevision,
                flyToBoundsPadding: padding,
                achievementOverlay: _overlay,
                extraJavaScriptChannels: [
                  BaseMapJavaScriptChannel(
                    name: 'onAchievementRegionSelected',
                    onMessageReceived: (message) {
                      final id = int.tryParse(message);
                      if (id != null) _focusRegion(id);
                    },
                  ),
                ],
              )
            else
              Center(
                child: _mapError
                    ? TextButton.icon(
                        onPressed: _loadRenderer,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('achievement.map.retry')),
                      )
                    : const CircularProgressIndicator(),
              ),
            Positioned(
              top: top,
              left: horizontalInset + 16,
              right: horizontalInset + 16,
              child: PointerInterceptor(
                child: country == null
                    ? AchievementGlobeSummary(stats: stats)
                    : Align(
                        alignment: Alignment.topLeft,
                        child: JourneyInfoPanelSurface(
                          backgroundAlpha: 0.76,
                          child: TextButton.icon(
                            onPressed: _showGlobe,
                            icon: const Icon(Icons.public_rounded, size: 18),
                            label: Text(context.tr('achievement.map.globe')),
                            style: TextButton.styleFrom(
                              foregroundColor: context.appColors.deepGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (_loadingCountry)
              Positioned(
                top: top + (country == null ? 144 : 48),
                left: 32,
                right: 32,
                child: const LinearProgressIndicator(),
              ),
            Positioned(
              left: horizontalInset + 16,
              right: horizontalInset + 16,
              bottom: bottom,
              child: PointerInterceptor(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_expanded && country != null && _detail != null) ...[
                      SizedBox(
                        height: regionStripHeight,
                        child: AchievementRegionStrip(
                          key: ValueKey(country.entityId.field0),
                          country: (
                            id: country.entityId.field0,
                            name: _detail!.node.displayName(_worldviewId),
                            visitedKm2:
                                _detail!.node.visitedAreaM2.toDouble() /
                                1000000,
                            totalKm2:
                                _detail!.node.totalAreaM2.toDouble() / 1000000,
                          ),
                          onRanking: _showRanking,
                          regions: regions
                              .map(
                                (entry) => (
                                  id: entry.key.field0,
                                  name: entry.value.displayName(_worldviewId),
                                  visitedKm2:
                                      entry.value.visitedAreaM2.toDouble() /
                                      1000000,
                                  totalKm2:
                                      entry.value.totalAreaM2.toDouble() /
                                      1000000,
                                ),
                              )
                              .toList(),
                          selectedId: _selectedRegionId,
                          onSelected: (id) =>
                              id == null ? _focusCountry() : _focusRegion(id),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Center(
                      child: SizedBox(
                        width: math.min(
                          constraints.maxWidth - horizontalInset * 2 - 32,
                          MediaQuery.orientationOf(context) ==
                                  Orientation.landscape
                              ? 720.0
                              : 480.0,
                        ),
                        child: AchievementPicker(
                          expanded: _expanded,
                          height: cardHeight,
                          onToggle: () =>
                              setState(() => _expanded = !_expanded),
                          child: widget.cardBuilder(
                            (country) => unawaited(_selectCountry(country)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
