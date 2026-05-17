use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

static STATIC: LazyLock<(StaticScreen, String)> =
    LazyLock::new(|| parse_static(include_str!("data/settings.json"), "settings.json"));

static FULL_SIZE: LazyLock<usize> =
    LazyLock::new(|| serde_json::to_vec(&SettingsScreen.full_response()).unwrap().len());

pub struct SettingsScreen;

impl Screen for SettingsScreen {
    fn id(&self) -> &'static str { "settings" }
    fn cache_key(&self) -> &'static str { &STATIC.1 }
    fn static_screen(&self) -> &'static StaticScreen { &STATIC.0 }
    fn full_response_size(&self) -> usize { *FULL_SIZE }

    fn dynamic_data(&self) -> Value {
        json!({
            "row_edit_profile": { "subtitle": "Tagir Fayrushin" },
            "row_change_email": { "subtitle": "t****@gmail.com" },
            "row_change_phone": { "subtitle": "+7 *** *** 42"   },
            "toggle_push":      { "enabled": true  },
            "toggle_email":     { "enabled": false },
            "toggle_sms":       { "enabled": false },
            "toggle_private":   { "enabled": false }
        })
    }
}
