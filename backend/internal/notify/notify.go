// Package notify envía avisos a los celulares (notificaciones push).
package notify

import (
	"context"
	"log/slog"
)

// MovementEvent es lo mínimo que hace falta para avisarle a la otra persona.
type MovementEvent struct {
	Type       string // INSERT, UPDATE o DELETE
	LedgerID   string
	MovementID string
	PayerID    string
	CreatedBy  string
	Concept    string
	Amount     int64
	Kind       string // expense o settlement
}

// Notifier avisa a la otra persona de la cuenta cuando algo cambia.
type Notifier interface {
	MovementChanged(ctx context.Context, event MovementEvent) error
}

// LogNotifier solo escribe en el log. Se reemplaza por un notificador de APNs
// cuando la app tenga la capacidad de notificaciones push.
type LogNotifier struct {
	Logger *slog.Logger
}

func (n LogNotifier) MovementChanged(_ context.Context, e MovementEvent) error {
	n.Logger.Info("movimiento cambió",
		"type", e.Type,
		"ledger", e.LedgerID,
		"movement", e.MovementID,
		"kind", e.Kind,
		"amount", e.Amount,
		"created_by", e.CreatedBy,
	)
	return nil
}
