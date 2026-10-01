import type { FeatureCollection, Geometry } from "geojson";
import type { GeoJSONSource, Map as MapLibreMap } from "maplibre-gl";

export interface AchievementOverlayData {
  features: FeatureCollection<Geometry>;
  selectedId: number | null;
}

declare global {
  interface Window {
    onAchievementRegionSelected?: { postMessage: (message: string) => void };
  }
}

const sourceId = "achievement-regions";
const fillId = "achievement-region-hit-area";
const lineId = "achievement-region-outline";
const selectedId = "achievement-region-selected";

/** Statistics live in Flutter cards; the map only shows boundaries and a
 * restrained fill for explored regions. Map taps and cards share selection.
 */
export class AchievementOverlay {
  private data: AchievementOverlayData | null = null;

  constructor(private map: MapLibreMap) {
    map.on("style.load", () => this.syncSource());
    map.on("click", (event) => {
      if (!this.data || !map.getLayer(fillId)) return;
      const hit = map
        .queryRenderedFeatures(event.point, { layers: [fillId] })
        .find((feature) => feature.properties.visited === true);
      if (hit)
        window.onAchievementRegionSelected?.postMessage(
          String(hit.properties.id),
        );
    });
  }

  setData(data: AchievementOverlayData | null): void {
    this.data = data;
    this.syncSource();
  }

  private syncSource(): void {
    if (!this.map.getStyle()) return;
    const empty: FeatureCollection = {
      type: "FeatureCollection",
      features: [],
    };
    const source = this.map.getSource(sourceId) as GeoJSONSource | undefined;
    if (source) source.setData(this.data?.features ?? empty);
    else if (this.data) {
      this.map.addSource(sourceId, {
        type: "geojson",
        data: this.data.features,
      });
      this.map.addLayer({
        id: fillId,
        type: "fill",
        source: sourceId,
        paint: {
          "fill-color": "#27664c",
          "fill-opacity": ["case", ["==", ["get", "visited"], true], 0.09, 0],
        },
      });
      this.map.addLayer({
        id: lineId,
        type: "line",
        source: sourceId,
        layout: { "line-join": "round", "line-cap": "round" },
        paint: {
          "line-color": "#14583f",
          "line-width": 3,
          "line-opacity": 0.9,
        },
      });
      this.map.addLayer({
        id: selectedId,
        type: "line",
        source: sourceId,
        layout: { "line-join": "round", "line-cap": "round" },
        paint: {
          "line-color": "#65a887",
          "line-width": 5,
          "line-opacity": 0.95,
        },
      });
    }
    if (this.map.getLayer(selectedId)) {
      this.map.setFilter(selectedId, [
        "==",
        ["get", "id"],
        this.data?.selectedId ?? -1,
      ]);
    }
  }
}
