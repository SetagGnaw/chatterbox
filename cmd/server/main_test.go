package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestEndpoints(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantStatus int
		wantState  string
	}{
		{name: "root", path: "/", wantStatus: http.StatusOK},
		{name: "health", path: "/healthz", wantStatus: http.StatusOK, wantState: "healthy"},
		{name: "ready", path: "/readyz", wantStatus: http.StatusOK, wantState: "ready"},
		{name: "missing", path: "/missing", wantStatus: http.StatusNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, tt.path, nil)
			recorder := httptest.NewRecorder()
			newHandler().ServeHTTP(recorder, request)

			if recorder.Code != tt.wantStatus {
				t.Fatalf("status=%d, want=%d", recorder.Code, tt.wantStatus)
			}
			if tt.wantState == "" {
				return
			}

			var got response
			if err := json.NewDecoder(recorder.Body).Decode(&got); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if got.Status != tt.wantState {
				t.Fatalf("state=%q, want=%q", got.Status, tt.wantState)
			}
			if got.Version != version {
				t.Fatalf("version=%q, want=%q", got.Version, version)
			}
		})
	}
}
