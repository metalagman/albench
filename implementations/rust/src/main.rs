use std::{
    collections::HashMap,
    net::SocketAddr,
    sync::{atomic::AtomicU64, Arc, RwLock},
};
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;
use server::{create_router, AppState};

#[tokio::main]
async fn main() {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .json()
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");

    let state = AppState {
        items: Arc::new(RwLock::new(HashMap::new())),
        next_id: Arc::new(AtomicU64::new(1)),
        request_count: Arc::new(AtomicU64::new(0)),
    };

    let app = create_router(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    info!("starting albench rust server on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
