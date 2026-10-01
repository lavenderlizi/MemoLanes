//! The map and achievement statistics must address exactly the same entities.
use std::{collections::BTreeSet, path::Path};

use geo_data_format::{GeoData, GeoEntityKind, Worldview};
use serde_json::Value;

#[test]
fn map_countries_contain_their_resolved_administrative_children() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/geo");
    for worldview in Worldview::ALL {
        let id = worldview.spec().id;
        let data = GeoData::open(&dir.join(format!("geo_data_{id}.bin"))).unwrap();
        let entities = data.entities().unwrap();
        for country in entities.iter().filter(|e| e.kind == GeoEntityKind::Admin0) {
            let path = dir.join(format!("map_geometry_{id}_{}.json", country.id.0));
            let bytes = std::fs::read(&path).expect("run just rasterize-geo first");
            let features: serde_json::Map<String, Value> = serde_json::from_slice(&bytes).unwrap();
            let expected: BTreeSet<String> = entities
                .iter()
                .filter(|e| e.id == country.id || e.parent_id == Some(country.id))
                .map(|e| e.id.0.to_string())
                .collect();
            assert_eq!(
                features.keys().cloned().collect::<BTreeSet<_>>(),
                expected,
                "{}",
                path.display()
            );
            for feature in features.values() {
                assert_eq!(feature["geometry"]["type"], "MultiPolygon");
                assert!(!feature["geometry"]["coordinates"]
                    .as_array()
                    .unwrap()
                    .is_empty());
                let anchor = feature["anchor"]
                    .as_array()
                    .expect("region has a label anchor");
                assert!(anchor[0].as_f64().unwrap().abs() <= 180.0);
                assert!(anchor[1].as_f64().unwrap().abs() <= 90.0);
            }
        }
    }
}
