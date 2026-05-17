use serde::{Deserialize, Serialize};
use serde_json::Value;

/// One node in the component tree.
/// `props` and `style` stay as `Value` — their shape varies per component type
/// and is purposely left open for the client renderer to interpret.
#[derive(Serialize, Deserialize, Clone)]
pub struct Component {
    #[serde(rename = "type")]
    pub kind: String,
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub props: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub style: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub children: Option<Vec<Component>>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub item_template: Option<Box<Component>>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct NavigationConfig {
    pub tab_bar: bool,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tab_index: Option<u8>,
    pub back_button: bool,
    pub title: String,
}

/// The immutable part of a screen — structure, layout, component hierarchy.
/// This is the part that gets cached on the client and hashed into `cache_key`.
#[derive(Serialize, Deserialize, Clone)]
pub struct StaticScreen {
    pub screen_id: String,
    pub layout: String,
    pub navigation: NavigationConfig,
    pub components: Vec<Component>,
}
