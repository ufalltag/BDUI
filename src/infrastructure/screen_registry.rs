use std::collections::HashMap;
use crate::domain::screen::{Screen, ScreenRepository};

/// HashMap-backed implementation of `ScreenRepository`.
///
/// Built via a fluent `register()` builder — adding a new screen requires
/// only one extra `.register(NewScreen)` call in `register_all()`.
/// Nothing else changes (Open/Closed principle).
pub struct ScreenRegistry {
    screens: HashMap<&'static str, Box<dyn Screen>>,
}

impl ScreenRegistry {
    pub fn new() -> Self {
        Self { screens: HashMap::new() }
    }

    /// Registers a screen and returns `self` for chaining.
    pub fn register(mut self, screen: impl Screen + 'static) -> Self {
        self.screens.insert(screen.id(), Box::new(screen));
        self
    }
}

impl Default for ScreenRegistry {
    fn default() -> Self { Self::new() }
}

impl ScreenRepository for ScreenRegistry {
    fn find(&self, id: &str) -> Option<&dyn Screen> {
        self.screens.get(id).map(|b| b.as_ref())
    }

    fn all_ids(&self) -> Vec<&'static str> {
        let mut ids: Vec<_> = self.screens.keys().copied().collect();
        ids.sort_unstable();
        ids
    }
}
