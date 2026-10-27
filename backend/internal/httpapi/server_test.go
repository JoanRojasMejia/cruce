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

// Un borrado suave llega como UPDATE con deleted_at y también se avisa.
func TestWebhookNotifiesOnSoftDelete(t *testing.T) {
	s, rec := newTestServer()
	body := `{"type":"UPDATE","table":"movements","schema":"public","record":{
		"id":"m1","ledger_id":"l1","kind":"expense","payer_id":"joan","amount":36000,
		"concept":"Almuerzo","created_by":"joan","deleted_at":"2026-10-27T12:05:00+00:00"},
		"old_record":{"id":"m1","ledger_id":"l1","kind":"expense","amount":36000}}`
	req := httptest.NewRequest(http.MethodPost, "/webhooks/movements", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer secreto")
	res := httptest.NewRecorder()
	s.Routes().ServeHTTP(res, req)
	if res.Code != http.StatusAccepted {
		t.Fatalf("esperaba 202, llegó %d: %s", res.Code, res.Body.String())
	}
	if len(rec.events) != 1 || rec.events[0].Type != "UPDATE" || rec.events[0].MovementID != "m1" {
		t.Fatalf("evento inesperado: %+v", rec.events)
	}
}

// Un aviso rechazado deja una advertencia con el motivo, sin el secreto ni el cuerpo que llegaron.
func TestWebhookLogsRejections(t *testing.T) {
	cases := []struct {
		name   string
		auth   string
		body   string
		status int
		reason string
	}{
		{"secreto incorrecto", "Bearer secreto-filtrado", `{"table":"movements"}`, http.StatusUnauthorized, "no autorizado"},
		{"sin header", "", `{"table":"movements"}`, http.StatusUnauthorized, "no autorizado"},
		{"JSON inválido", "Bearer secreto", `{"concept":"Mercado Éxito"`, http.StatusBadRequest, "JSON inválido"},
		{"otra tabla", "Bearer secreto", `{"table":"profiles","record":{"id":"x","concept":"Mercado Éxito"}}`, http.StatusBadRequest, "tabla inesperada"},
		{"sin registro", "Bearer secreto", `{"type":"INSERT","table":"movements"}`, http.StatusBadRequest, "sin registro"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			var logs strings.Builder
			rec := &recorder{}
			s := NewServer("secreto", rec, slog.New(slog.NewJSONHandler(&logs, nil)))
			req := httptest.NewRequest(http.MethodPost, "/webhooks/movements", strings.NewReader(c.body))
			if c.auth != "" {
				req.Header.Set("Authorization", c.auth)
			}
			res := httptest.NewRecorder()
			s.Routes().ServeHTTP(res, req)
			if res.Code != c.status {
				t.Fatalf("esperaba %d, llegó %d", c.status, res.Code)
			}
			if len(rec.events) != 0 {
				t.Fatal("no debía notificar")
			}
			line := logs.String()
			if !strings.Contains(line, `"level":"WARN"`) || !strings.Contains(line, c.reason) {
				t.Fatalf("esperaba una advertencia con %q, quedó: %s", c.reason, line)
			}
			for _, secret := range []string{"secreto-filtrado", "Mercado Éxito", "Bearer"} {
				if strings.Contains(line, secret) {
					t.Fatalf("el log no debía contener %q: %s", secret, line)
				}
			}
		})
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
