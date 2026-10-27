// Package httpapi expone el servicio HTTP de Cruce.
//
// La app habla directo con Supabase para leer y escribir movimientos.
// Este servicio solo hace lo que Supabase no resuelve solo:
//   - recibir los Database Webhooks de la tabla movements y avisar a la otra persona;
//   - (próximo) recordatorio mensual para saldar y limpieza de invitaciones vencidas.
package httpapi

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/joanrojas/cruce/backend/internal/notify"
)

const maxBody = 1 << 20 // 1 MB

type Server struct {
	webhookSecret string
	notifier      notify.Notifier
	logger        *slog.Logger
}

func NewServer(webhookSecret string, notifier notify.Notifier, logger *slog.Logger) *Server {
	return &Server{webhookSecret: webhookSecret, notifier: notifier, logger: logger}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("POST /webhooks/movements", s.handleMovementWebhook)
	return mux
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// webhookPayload es el formato que envían los Database Webhooks de Supabase.
type webhookPayload struct {
	Type      string          `json:"type"`
	Table     string          `json:"table"`
	Schema    string          `json:"schema"`
	Record    *movementRecord `json:"record"`
	OldRecord *movementRecord `json:"old_record"`
}

type movementRecord struct {
	ID        string `json:"id"`
	LedgerID  string `json:"ledger_id"`
	Kind      string `json:"kind"`
	PayerID   string `json:"payer_id"`
	Amount    int64  `json:"amount"`
	Concept   string `json:"concept"`
	CreatedBy string `json:"created_by"`
}

func (s *Server) handleMovementWebhook(w http.ResponseWriter, r *http.Request) {
	if !s.authorized(r) {
		s.reject(w, http.StatusUnauthorized, "no autorizado")
		return
	}

	var payload webhookPayload
	if err := json.NewDecoder(io.LimitReader(r.Body, maxBody)).Decode(&payload); err != nil {
		s.reject(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	if payload.Table != "movements" {
		s.reject(w, http.StatusBadRequest, "tabla inesperada")
		return
	}

	record := payload.Record
	if record == nil {
		record = payload.OldRecord
	}
	if record == nil {
		s.reject(w, http.StatusBadRequest, "sin registro")
		return
	}

	event := notify.MovementEvent{
		Type:       payload.Type,
		LedgerID:   record.LedgerID,
		MovementID: record.ID,
		PayerID:    record.PayerID,
		CreatedBy:  record.CreatedBy,
		Concept:    record.Concept,
		Amount:     record.Amount,
		Kind:       record.Kind,
	}
	if err := s.notifier.MovementChanged(r.Context(), event); err != nil {
		s.logger.Error("no se pudo notificar", "err", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "no se pudo notificar"})
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]string{"status": "recibido"})
}

// reject responde con el error y deja una advertencia en el log con el motivo. Nunca escribe el header ni el
// cuerpo que llegaron: pueden traer el secreto o el concepto de un movimiento.
func (s *Server) reject(w http.ResponseWriter, status int, reason string) {
	s.logger.Warn("webhook rechazado", "motivo", reason, "status", status)
	writeJSON(w, status, map[string]string{"error": reason})
}

// authorized compara el header Authorization: Bearer <secreto> en tiempo constante.
func (s *Server) authorized(r *http.Request) bool {
	const prefix = "Bearer "
	header := r.Header.Get("Authorization")
	if len(header) <= len(prefix) || header[:len(prefix)] != prefix {
		return false
	}
	token := header[len(prefix):]
	return subtle.ConstantTimeCompare([]byte(token), []byte(s.webhookSecret)) == 1
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil && !errors.Is(err, http.ErrHandlerTimeout) {
		slog.Default().Warn("no se pudo escribir la respuesta", "err", err)
	}
}
