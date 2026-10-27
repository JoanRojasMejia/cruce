package notify

import (
	"context"
	"log/slog"
	"strings"
	"testing"
)

// La línea de un movimiento lleva ids, tipos y montos, pero nunca el concepto.
func TestLogNotifierOmitsConcept(t *testing.T) {
	var logs strings.Builder
	n := LogNotifier{Logger: slog.New(slog.NewJSONHandler(&logs, nil))}
	err := n.MovementChanged(context.Background(), MovementEvent{
		Type: "INSERT", LedgerID: "l1", MovementID: "m1", PayerID: "joan", CreatedBy: "joan",
		Concept: "Mercado Éxito", Amount: 100000, Kind: "expense",
	})
	if err != nil {
		t.Fatal(err)
	}
	line := logs.String()
	if strings.Contains(line, "Mercado Éxito") {
		t.Fatalf("el log no debía contener el concepto: %s", line)
	}
	for _, want := range []string{`"type":"INSERT"`, `"ledger":"l1"`, `"movement":"m1"`, `"amount":100000`, `"kind":"expense"`, `"created_by":"joan"`} {
		if !strings.Contains(line, want) {
			t.Fatalf("faltaba %s en el log: %s", want, line)
		}
	}
}
