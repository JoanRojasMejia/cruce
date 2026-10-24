package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/joanrojas/cruce/backend/internal/notify"
)

type recorder struct{ events []notify.MovementEvent }

func (r *recorder) MovementChanged(_ context.Context, e notify.MovementEvent) error {
	r.events = append(r.events, e)
	return nil
}

func newTestServer() (*Server, *recorder) {
	rec := &recorder{}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewServer("secreto", rec, logger), rec
}

func TestHealth(t *testing.T) {
	s, _ := newTestServer()
	res := httptest.NewRecorder()
	s.Routes().ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if res.Code != http.StatusOK {
		t.Fatalf("esperaba 200, llegó %d", res.Code)
	}
}

func TestWebhookRejectsWrongSecret(t *testing.T) {
	s, rec := newTestServer()
	req := httptest.NewRequest(http.MethodPost, "/webhooks/movements", strings.NewReader(`{}`))
	req.Header.Set("Authorization", "Bearer otro")
	res := httptest.NewRecorder()
	s.Routes().ServeHTTP(res, req)
	if res.Code != http.StatusUnauthorized {
		t.Fatalf("esperaba 401, llegó %d", res.Code)
	}
	if len(rec.events) != 0 {
		t.Fatal("no debía notificar")
	}
}

func TestWebhookNotifiesOnInsert(t *testing.T) {
	s, rec := newTestServer()
	body := `{"type":"INSERT","table":"movements","schema":"public","record":{
		"id":"m1","ledger_id":"l1","kind":"expense","payer_id":"joan","amount":36000,
		"concept":"Almuerzo corrientazo","created_by":"joan"},"old_record":null}`
	req := httptest.NewRequest(http.MethodPost, "/webhooks/movements", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer secreto")
	res := httptest.NewRecorder()
	s.Routes().ServeHTTP(res, req)
	if res.Code != http.StatusAccepted {
		t.Fatalf("esperaba 202, llegó %d: %s", res.Code, res.Body.String())
	}
	if len(rec.events) != 1 || rec.events[0].Amount != 36000 || rec.events[0].Type != "INSERT" {
		t.Fatalf("evento inesperado: %+v", rec.events)
	}
}

func TestWebhookRejectsOtherTables(t *testing.T) {
	s, _ := newTestServer()
	req := httptest.NewRequest(http.MethodPost, "/webhooks/movements",
		strings.NewReader(`{"type":"INSERT","table":"profiles","record":{"id":"x"}}`))
	req.Header.Set("Authorization", "Bearer secreto")
	res := httptest.NewRecorder()
	s.Routes().ServeHTTP(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("esperaba 400, llegó %d", res.Code)
	}
}
