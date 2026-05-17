use std::sync::LazyLock;
use serde_json::{json, Value};
use crate::domain::{screen::Screen, ui::StaticScreen};
use super::parse_static;

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
        json!({
            "stories": [
                { "id": "s1", "user": "alice", "avatar": "https://example.com/avatars/alice.jpg", "seen": false },
                { "id": "s2", "user": "bob",   "avatar": "https://example.com/avatars/bob.jpg",   "seen": true  },
                { "id": "s3", "user": "carol", "avatar": "https://example.com/avatars/carol.jpg", "seen": false },
                { "id": "s4", "user": "dan",   "avatar": "https://example.com/avatars/dan.jpg",   "seen": false }
            ],
            "feed": [
                {
                    "id": "f1",
                    "author": "alice", "author_avatar": "https://example.com/avatars/alice.jpg",
                    "media_url": "https://example.com/posts/f1.jpg",
                    "likes": 1204, "liked": false, "bookmarked": false,
                    "caption": "Beautiful sunset at the mountains!",
                    "created_at": "2026-05-17T08:00:00Z"
                },
                {
                    "id": "f2",
                    "author": "bob", "author_avatar": "https://example.com/avatars/bob.jpg",
                    "media_url": "https://example.com/posts/f2.jpg",
                    "likes": 857, "liked": true, "bookmarked": true,
                    "caption": "My new Rust project is coming along nicely",
                    "created_at": "2026-05-17T06:30:00Z"
                }
            ]
        })
    }
}
