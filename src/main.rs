mod echo;
mod handlers;

use axum::{Router, routing::{get, post}};

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let app = Router::new()
        .route("/v1/chat/completions", post(handlers::chat::handler))
        .route("/v1/completions", post(handlers::completions::handler))
        .route("/v1/responses", post(handlers::responses::handler))
        .route("/v1/messages", post(handlers::anthropic::handler))
        .route("/v1/tool-parse", post(handlers::tool_parse::handler))
        .route("/health", get(|| async { "ok" }));

    let addr = "0.0.0.0:3000";
    tracing::info!("Dynamo demo server listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
