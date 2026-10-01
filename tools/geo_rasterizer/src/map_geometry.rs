//! Compact vector companions to the raster statistics, using the same policy
//! and frozen entity IDs. Hierarchy membership is supplied by the runtime index.
use std::{collections::BTreeMap, path::Path};

use anyhow::Result;
use geo::{InteriorPoint, MapCoords, Simplify};
use geo_data_format::{GeoEntity, GeoEntityKind};
use geo_types::MultiPolygon;
use serde_json::{json, Value};

use crate::{atomic_write::write_atomically, entities::EntityModel};

fn feature(geometry: &MultiPolygon<f64>) -> Value {
    let simplified = geometry
        .simplify(0.005)
        .map_coords(|coord| geo_types::Coord {
            x: (coord.x * 100_000.0).round() / 100_000.0,
            y: (coord.y * 100_000.0).round() / 100_000.0,
        });
    let anchor = geometry.interior_point().map(|p| [p.x(), p.y()]);
    json!({
        "geometry": geojson::Geometry::new(geojson::GeometryValue::from(&simplified)),
        "anchor": anchor,
    })
}

pub fn write_map_geometry(
    model: &EntityModel,
    entities: &[GeoEntity],
    dir: &Path,
    worldview: &str,
) -> Result<()> {
    // Partition by the resolved raster hierarchy, not source country codes:
    // worldview policy may reparent provinces. Flutter only loads one country.
    for country in entities.iter().filter(|e| e.kind == GeoEntityKind::Admin0) {
        let mut features = BTreeMap::new();
        if let Some(geometry) = model.geometry_for_country.get(&country.canonical_code) {
            features.insert(country.id.0.to_string(), feature(geometry));
        }
        for province in entities.iter().filter(|e| e.parent_id == Some(country.id)) {
            if let Some(geometry) = model.geometry_for_province.get(&province.canonical_code) {
                features.insert(province.id.0.to_string(), feature(geometry));
            }
        }
        let path = dir.join(format!("map_geometry_{worldview}_{}.json", country.id.0));
        write_atomically(&path, &serde_json::to_vec(&features)?)?;
    }
    Ok(())
}
