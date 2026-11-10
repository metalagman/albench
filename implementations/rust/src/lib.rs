use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, RwLock,
    },
    time::Instant,
};
use tracing::info;

#[derive(Clone, Serialize, Deserialize)]
pub struct Item {
    pub id: String,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub created_at: String,
}

#[derive(Deserialize)]
pub struct CreateItemRequest {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    pub code: u16,
    pub message: String,
}

#[derive(Clone)]
pub struct AppState {
    pub items: Arc<RwLock<HashMap<String, Item>>>,
    pub next_id: Arc<AtomicU64>,
    pub request_count: Arc<AtomicU64>,
}

async fn health_check(State(state): State<AppState>) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);
    let resp = Json(serde_json::json!({ "status": "ok" }));
    info!(method = "GET", path = "/healthz", duration_ms = ?start.elapsed().as_millis());
    resp
}

async fn ready_check(State(state): State<AppState>) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);
    let resp = Json(serde_json::json!({ "ready": true }));
    info!(method = "GET", path = "/readyz", duration_ms = ?start.elapsed().as_millis());
    resp
}

async fn metrics(State(state): State<AppState>) -> impl IntoResponse {
    let count = state.request_count.load(Ordering::Relaxed);
    let body = format!(
        "# HELP http_requests_total Total number of HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total {}\n",
        count
    );
    Response::builder()
        .header("Content-Type", "text/plain; version=0.0.4")
        .body(body)
        .unwrap()
}

async fn list_items(State(state): State<AppState>) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);
    let items = state.items.read().unwrap();
    let list: Vec<Item> = items.values().cloned().collect();
    info!(method = "GET", path = "/api/v1/items", count = list.len(), duration_ms = ?start.elapsed().as_millis());
    Json(list)
}

async fn create_item(
    State(state): State<AppState>,
    Json(req): Json<CreateItemRequest>,
) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);

    if req.name.trim().is_empty() {
        return (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                code: 400,
                message: "name is required".to_string(),
            }),
        )
            .into_response();
    }

    let id = state.next_id.fetch_add(1, Ordering::Relaxed).to_string();
    let now = "2026-11-10T09:00:00Z".to_string();
    let item = Item {
        id: id.clone(),
        name: req.name,
        description: req.description,
        created_at: now,
    };

    state.items.write().unwrap().insert(id, item.clone());
    info!(method = "POST", path = "/api/v1/items", id = %item.id, duration_ms = ?start.elapsed().as_millis());

    (StatusCode::CREATED, Json(item)).into_response()
}

async fn get_item(State(state): State<AppState>, Path(id): Path<String>) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);
    let items = state.items.read().unwrap();
    if let Some(item) = items.get(&id) {
        info!(method = "GET", path = "/api/v1/items/{id}", id = %id, duration_ms = ?start.elapsed().as_millis());
        (StatusCode::OK, Json(item.clone())).into_response()
    } else {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                code: 404,
                message: "item not found".to_string(),
            }),
        )
            .into_response()
    }
}

async fn delete_item(State(state): State<AppState>, Path(id): Path<String>) -> impl IntoResponse {
    let start = Instant::now();
    state.request_count.fetch_add(1, Ordering::Relaxed);
    let mut items = state.items.write().unwrap();
    if items.remove(&id).is_some() {
        info!(method = "DELETE", path = "/api/v1/items/{id}", id = %id, duration_ms = ?start.elapsed().as_millis());
        StatusCode::NO_CONTENT.into_response()
    } else {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                code: 404,
                message: "item not found".to_string(),
            }),
        )
            .into_response()
    }
}

pub fn create_router(state: AppState) -> Router {
    Router::new()
        .route("/healthz", get(health_check))
        .route("/readyz", get(ready_check))
        .route("/metrics", get(metrics))
        .route("/api/v1/items", get(list_items).post(create_item))
        .route("/api/v1/items/:id", get(get_item).delete(delete_item))
        .with_state(state)
}
