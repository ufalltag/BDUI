use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

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
        json!({
            "filters": [
                { "id": "all",         "label": "All",         "selected": true  },
                { "id": "electronics", "label": "Electronics", "selected": false },
                { "id": "clothing",    "label": "Clothing",    "selected": false },
                { "id": "books",       "label": "Books",       "selected": false },
                { "id": "sports",      "label": "Sports",      "selected": false }
            ],
            "products": [
                { "id": "prod_1", "name": "Wireless Headphones Pro",  "price": "$129.99", "rating": 4.7, "reviews": 2341, "badge": "Best Seller", "in_cart": false },
                { "id": "prod_2", "name": "Mechanical Keyboard TKL",  "price": "$89.99",  "rating": 4.5, "reviews": 876,  "badge": null,          "in_cart": false },
                { "id": "prod_3", "name": "USB-C Hub 7-in-1",         "price": "$49.99",  "rating": 4.3, "reviews": 1102, "badge": "Sale",         "in_cart": true  },
                { "id": "prod_4", "name": "Ergonomic Mouse",          "price": "$59.99",  "rating": 4.6, "reviews": 554,  "badge": null,          "in_cart": false }
            ],
            "total_count": 128,
            "current_page": 1
        })
    }
}
