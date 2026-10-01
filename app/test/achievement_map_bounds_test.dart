import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/achievement/achievement_map_view.dart';
import 'package:memolanes/src/rust/achievement/region.dart';
import 'package:memolanes/src/rust/api/achievement.dart';

void main() {
  test(
    'region cards and ranking omit unvisited regions and sort explored area',
    () {
      RegionEntity region(int visited) => RegionEntity(
        kind: RegionKind.admin1,
        nameKey: const RegionNameKey(value: 'test'),
        visitedAreaM2: BigInt.from(visited),
        totalAreaM2: BigInt.from(1000),
      );
      final detail = RegionDetail(
        entityId: const GeoEntityId(field0: 1),
        node: region(120),
        children: {
          const GeoEntityId(field0: 2): region(0),
          const GeoEntityId(field0: 3): region(20),
          const GeoEntityId(field0: 4): region(100),
        },
      );
      expect(
        exploredAchievementRegions(detail).map((entry) => entry.key.field0),
        [4, 3],
      );
    },
  );

  test('country fit includes distant islands and all latitudes', () {
    final bounds = achievementGeometryBounds({
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [
            [10, 40],
            [20, 40],
            [20, 50],
            [10, 40],
          ],
        ],
        [
          [
            [-60, -20],
            [-59, -20],
            [-59, -19],
            [-60, -20],
          ],
        ],
      ],
    })!;
    expect(bounds.west, -60);
    expect(bounds.east, 20);
    expect(bounds.south, -20);
    expect(bounds.north, 50);
  });

  test('country on both sides of the date line uses the narrow interval', () {
    final bounds = achievementGeometryBounds({
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [
            [175, -20],
            [180, -20],
            [180, -15],
            [175, -20],
          ],
        ],
        [
          [
            [-180, -20],
            [-175, -20],
            [-175, -15],
            [-180, -20],
          ],
        ],
      ],
    })!;
    expect(bounds.west, 175);
    expect(bounds.east, 185);
    expect(bounds.east - bounds.west, 10);
  });

  test('empty geometry does not replace the current camera', () {
    expect(
      achievementGeometryBounds({'type': 'MultiPolygon', 'coordinates': []}),
      isNull,
    );
  });
}
