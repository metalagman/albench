package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

type Item struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
	CreatedAt   string `json:"created_at"`
}

type CreateItemRequest struct {
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
}

type ErrorResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type Server struct {
	logger       *slog.Logger
	mu           sync.RWMutex
	items        map[string]Item
	nextID       uint64
	requestCount atomic.Uint64
}

func NewServer() *Server {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	return &Server{
		logger: logger,
		items:  make(map[string]Item),
	}
}

func (s *Server) withMetricsAndLogging(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		s.requestCount.Add(1)
		next(w, r)
		s.logger.Info("http_request",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Duration("duration_ms", time.Since(start)),
		)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]bool{"ready": true})
}

func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	total := s.requestCount.Load()
	fmt.Fprintf(w, "# HELP http_requests_total Total number of HTTP requests\n")
	fmt.Fprintf(w, "# TYPE http_requests_total counter\n")
	fmt.Fprintf(w, "http_requests_total %d\n", total)
}

func (s *Server) handleListItems(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	itemsList := make([]Item, 0, len(s.items))
	for _, item := range s.items {
		itemsList = append(itemsList, item)
	}
	s.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(itemsList)
}

func (s *Server) handleCreateItem(w http.ResponseWriter, r *http.Request) {
	var req CreateItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(ErrorResponse{Code: 400, Message: "name is required"})
		return
	}

	idNum := atomic.AddUint64(&s.nextID, 1)
	item := Item{
		ID:          strconv.FormatUint(idNum, 10),
		Name:        req.Name,
		Description: req.Description,
		CreatedAt:   time.Now().UTC().Format(time.RFC3339),
	}

	s.mu.Lock()
	s.items[item.ID] = item
	s.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(item)
}

func (s *Server) handleGetItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	s.mu.RLock()
	item, exists := s.items[id]
	s.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(ErrorResponse{Code: 404, Message: "item not found"})
		return
	}
	_ = json.NewEncoder(w).Encode(item)
}

func (s *Server) handleDeleteItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	s.mu.Lock()
	_, exists := s.items[id]
	if exists {
		delete(s.items, id)
	}
	s.mu.Unlock()

	if !exists {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		_ = json.NewEncoder(w).Encode(ErrorResponse{Code: 404, Message: "item not found"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.withMetricsAndLogging(s.handleHealth))
	mux.HandleFunc("GET /readyz", s.withMetricsAndLogging(s.handleReady))
	mux.HandleFunc("GET /metrics", s.withMetricsAndLogging(s.handleMetrics))
	mux.HandleFunc("GET /api/v1/items", s.withMetricsAndLogging(s.handleListItems))
	mux.HandleFunc("POST /api/v1/items", s.withMetricsAndLogging(s.handleCreateItem))
	mux.HandleFunc("GET /api/v1/items/{id}", s.withMetricsAndLogging(s.handleGetItem))
	mux.HandleFunc("DELETE /api/v1/items/{id}", s.withMetricsAndLogging(s.handleDeleteItem))
	return mux
}

func main() {
	server := NewServer()
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	server.logger.Info("starting albench go server", slog.String("port", port))
	if err := http.ListenAndServe(":"+port, server.Routes()); err != nil {
		server.logger.Error("server failed", slog.String("error", err.Error()))
		os.Exit(1)
	}
}
