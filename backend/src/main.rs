//! All Love — API compartilhada pelo app mobile (Flutter) e pelo app desktop (Tauri + Svelte).

mod auth;
mod db;
mod demo;
mod error;
mod routes;
mod rules;

use std::{net::SocketAddr, path::PathBuf};

use axum::{extract::DefaultBodyLimit, Router};
use sqlx::SqlitePool;
use tower_http::{cors::CorsLayer, services::ServeDir, trace::TraceLayer};

#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub upload_dir: PathBuf,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "alllove_api=info,tower_http=info".into()),
        )
        .init();

    let database_url = std::env::var("DATABASE_URL").unwrap_or_else(|_| "sqlite://alllove.db".into());
    let upload_dir = PathBuf::from(std::env::var("UPLOAD_DIR").unwrap_or_else(|_| "uploads".into()));
    let port: u16 = std::env::var("PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(3000);

    std::fs::create_dir_all(&upload_dir).expect("não foi possível criar a pasta de uploads");
    let pool = db::connect(&database_url).await;
    db::seed(&pool).await;

    let state = AppState { db: pool, upload_dir: upload_dir.clone() };

    let app = Router::new()
        .nest("/api", routes::router())
        .nest_service("/uploads", ServeDir::new(upload_dir))
        .layer(DefaultBodyLimit::max(6 * 1024 * 1024))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("All Love API ouvindo em http://{addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
