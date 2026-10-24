// Package config lee la configuración del servicio desde variables de entorno.
package config

import (
	"errors"
	"os"
)

type Config struct {
	// Puerto HTTP. Por defecto 8080.
	Port string
	// URL del proyecto de Supabase (https://xxxx.supabase.co).
	SupabaseURL string
	// Llave service_role. Solo vive en el servidor, nunca en la app.
	SupabaseServiceRoleKey string
	// Secreto compartido con los Database Webhooks de Supabase.
	WebhookSecret string
}

func Load() (Config, error) {
	cfg := Config{
		Port:                   getenv("PORT", "8080"),
		SupabaseURL:            os.Getenv("SUPABASE_URL"),
		SupabaseServiceRoleKey: os.Getenv("SUPABASE_SERVICE_ROLE_KEY"),
		WebhookSecret:          os.Getenv("WEBHOOK_SECRET"),
	}
	if cfg.WebhookSecret == "" {
		return cfg, errors.New("falta WEBHOOK_SECRET")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
