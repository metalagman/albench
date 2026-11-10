use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use std::sync::{
    atomic::AtomicU64,
    Arc, RwLock,
};
use std::collections::HashMap;
use tower::util::ServiceExt;
use server::{create_router, AppState};

#[tokio::test]
async fn test_rust_endpoints() {
    let state = AppState {
        items: Arc::new(RwLock::new(HashMap::new())),
        next_id: Arc::new(AtomicU64::new(1)),
        request_count: Arc::new(AtomicU64::new(0)),
    };
    let app = create_router(state);

    // 1. Healthz
    let response = app
        .clone()
        .oneshot(Request::builder().uri("/healthz").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // 2. Metrics
    let response = app
        .clone()
        .oneshot(Request::builder().uri("/metrics").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // 3. Create Item
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/items")
                .header("Content-Type", "application/json")
                .body(Body::from(r#"{"name":"test-widget","description":"first"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CREATED);
}
