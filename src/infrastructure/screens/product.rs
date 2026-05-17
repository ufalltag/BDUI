use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

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
        json!({
            "product_name": "Wireless Headphones Pro",
            "product_brand": "SoundCore",
            "images": [
                "https://example.com/products/hp_1.jpg",
                "https://example.com/products/hp_2.jpg",
                "https://example.com/products/hp_3.jpg"
            ],
            "rating": 4.7,
            "review_count": 2341,
            "price": "$129.99",
            "price_original": "$179.99",
            "colors": [
                { "id": "black", "hex": "#1a1a1a", "selected": true  },
                { "id": "white", "hex": "#f5f5f5", "selected": false },
                { "id": "navy",  "hex": "#1e3a5f", "selected": false }
            ],
            "quantity": 1,
            "description": "Premium wireless headphones with active noise cancellation, 30-hour battery life, and Hi-Res Audio certification.",
            "reviews": [
                { "id": "r1", "user": "Alice M.", "rating": 5, "text": "Best headphones I've ever owned.", "date": "2026-05-10" },
                { "id": "r2", "user": "Bob K.",   "rating": 4, "text": "Great sound quality.",            "date": "2026-05-08" }
            ],
            "in_cart": false,
            "bookmarked": false
        })
    }
}
