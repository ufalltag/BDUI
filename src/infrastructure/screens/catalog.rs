use std::sync::LazyLock;
use serde_json::Value;
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::{parse_static, read_dynamic};

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/catalog.json"), "catalog.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&CatalogScreen.full_response()).unwrap().len());

pub struct CatalogScreen;

impl Screen for CatalogScreen {
    fn id(&self) -> &'static str { "catalog" }
    fn cache_key(&self) -> &'static str { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        self.dynamic_data_for(None)
    }

    /// Each category serves a completely different product set from its own
    /// JSON file. Unknown / missing category falls back to the default ("all").
    fn dynamic_data_for(&self, variant: Option<&str>) -> Value {
        let file = match variant {
            Some("electronics") => "catalog_electronics.json",
            Some("clothing")    => "catalog_clothing.json",
            Some("books")       => "catalog_books.json",
            Some("sports")      => "catalog_sports.json",
            _                    => "catalog_dynamic.json",
        };
        read_dynamic(file)
    }
}
