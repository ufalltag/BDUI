use std::sync::LazyLock;
use serde_json::Value;
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::{parse_static, read_dynamic};

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/home.json"), "home.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&HomeScreen.full_response()).unwrap().len());

pub struct HomeScreen;

impl Screen for HomeScreen {
    fn id(&self) -> &'static str { "home" }
    fn cache_key(&self) -> &'static str { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        read_dynamic("home_dynamic.json")
    }
}
