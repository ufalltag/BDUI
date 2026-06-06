use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use crate::application::screen_service::ScreenError;
use crate::domain::{models::BduiVersionError, protocol};

/// All HTTP-level errors the server can produce.
/// Each variant maps to a specific status code + JSON body.
pub enum AppError {
    ScreenNotFound,
    UnsupportedVersion { client_version: u8 },
    /// `X-BDUI-Version` header is present but not a valid u8 integer.
    MalformedVersionHeader,
}

impl From<ScreenError> for AppError {
    fn from(e: ScreenError) -> Self {
        match e {
            ScreenError::NotFound => AppError::ScreenNotFound,
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match self {
            Self::ScreenNotFound => (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({ "error": "screen_not_found" })),
            )
                .into_response(),

            Self::UnsupportedVersion { client_version } => (
                StatusCode::NOT_ACCEPTABLE,
                Json(BduiVersionError {
                    error: "unsupported_protocol_version",
                    client_version,
                    supported_versions: protocol::SUPPORTED.to_vec(),
                }),
            )
                .into_response(),

            Self::MalformedVersionHeader => (
                StatusCode::BAD_REQUEST,
                Json(serde_json::json!({ "error": "malformed_version_header" })),
            )
                .into_response(),
        }
    }
}
