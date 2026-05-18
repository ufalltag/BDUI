use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};

/// Recursively sorts JSON object keys so the output is deterministic
/// regardless of insertion order. Arrays and primitives are left unchanged.
fn canonicalize(value: Value) -> Value {
    match value {
        Value::Object(map) => {
            let mut entries: Vec<(String, Value)> = map
                .into_iter()
                .map(|(k, v)| (k, canonicalize(v)))
                .collect();
            entries.sort_by(|(a, _), (b, _)| a.cmp(b));
            Value::Object(entries.into_iter().collect())
        }
        Value::Array(arr) => Value::Array(arr.into_iter().map(canonicalize).collect()),
        other => other,
    }
}

/// SHA-256 of the canonical JSON form of `value`.
/// Keys at every nesting level are sorted before hashing, so the result is
/// independent of field declaration order in the source.
///
/// Returns a 64-char lowercase hex string.
pub fn compute_cache_key(value: &impl Serialize) -> String {
    let as_value = serde_json::to_value(value).expect("serialization never fails");
    let canonical = serde_json::to_string(&canonicalize(as_value)).expect("serialization never fails");
    let mut hasher = Sha256::new();
    hasher.update(canonical.as_bytes());
    hex::encode(hasher.finalize())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn stable_across_key_order() {
        let a = json!({ "layout": "Screen", "screen_id": "home" });
        let b = json!({ "screen_id": "home", "layout": "Screen" });
        assert_eq!(compute_cache_key(&a), compute_cache_key(&b));
    }

    #[test]
    fn changes_when_structure_changes() {
        let a = json!({ "layout": "ScreenV1" });
        let b = json!({ "layout": "ScreenV2" });
        assert_ne!(compute_cache_key(&a), compute_cache_key(&b));
    }

    #[test]
    fn produces_64_char_hex() {
        let key = compute_cache_key(&json!({ "x": 1 }));
        assert_eq!(key.len(), 64);
        assert!(key.chars().all(|c| c.is_ascii_hexdigit()));
    }
}
