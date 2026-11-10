package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGoServerEndpoints(t *testing.T) {
	server := NewServer()
	handler := server.Routes()

	// 1. Healthz
	req := httptest.NewRequest("GET", "/healthz", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	// 2. Metrics
	req = httptest.NewRequest("GET", "/metrics", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "http_requests_total") {
		t.Fatalf("unexpected metrics response: %s", rec.Body.String())
	}

	// 3. Create Item
	createBody := `{"name":"test-widget","description":"first item"}`
	req = httptest.NewRequest("POST", "/api/v1/items", bytes.NewBufferString(createBody))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", rec.Code)
	}
	var created Item
	if err := json.NewDecoder(rec.Body).Decode(&created); err != nil {
		t.Fatalf("failed to decode created item: %v", err)
	}
	if created.Name != "test-widget" || created.ID == "" {
		t.Fatalf("invalid created item data: %+v", created)
	}

	// 4. Get Item
	req = httptest.NewRequest("GET", "/api/v1/items/"+created.ID, nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	// 5. Delete Item
	req = httptest.NewRequest("DELETE", "/api/v1/items/"+created.ID, nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
}
