use std::sync::LazyLock;
use serde_json::Value;
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::{parse_static, read_dynamic};

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/profile.json"), "profile.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&ProfileScreen.full_response()).unwrap().len());

pub struct ProfileScreen;

impl Screen for ProfileScreen {
    fn id(&self) -> &'static str { "profile" }
    fn cache_key(&self) -> &'static str { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        read_dynamic("profile_dynamic.json")
    }
}
