use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

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
        json!({
            "username": "Tagir Fayrushin",
            "handle": "@tagir_dev",
            "bio": "iOS Developer · Building BDUI systems · Swift & Rust enthusiast",
            "avatar_url": "https://example.com/avatars/tagir.jpg",
            "posts_count": 142,
            "followers_count": 3800,
            "following_count": 210,
            "posts": [
                { "id": "p1", "thumbnail": "https://example.com/posts/p1.jpg", "likes": 312 },
                { "id": "p2", "thumbnail": "https://example.com/posts/p2.jpg", "likes": 204 },
                { "id": "p3", "thumbnail": "https://example.com/posts/p3.jpg", "likes": 519 },
                { "id": "p4", "thumbnail": "https://example.com/posts/p4.jpg", "likes": 88  },
                { "id": "p5", "thumbnail": "https://example.com/posts/p5.jpg", "likes": 731 },
                { "id": "p6", "thumbnail": "https://example.com/posts/p6.jpg", "likes": 156 }
            ]
        })
    }
}
