use std::sync::LazyLock;
use serde_json::Value;
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::{parse_static, read_dynamic};

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/product.json"), "product.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&ProductScreen.full_response()).unwrap().len());

pub struct ProductScreen;

impl Screen for ProductScreen {
    fn id(&self) -> &'static str { "product" }
    fn cache_key(&self) -> &'static str { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        self.dynamic_data_for(None)
    }

    /// Each colour variant serves a different image gallery from its own JSON
    /// file. Unknown / missing colour falls back to the default.
    fn dynamic_data_for(&self, variant: Option<&str>) -> Value {
        let file = match variant {
            Some("black") => "product_black.json",
            Some("white") => "product_white.json",
            Some("navy")  => "product_navy.json",
            _             => "product_dynamic.json",
        };
        read_dynamic(file)
    }
}
