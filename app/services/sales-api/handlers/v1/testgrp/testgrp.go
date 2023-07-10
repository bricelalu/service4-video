package testgrp

import (
	"context"
	"encoding/json"
	"net/http"
)

func Status(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	status := struct{ Status string }{Status: "ok"}
	return json.NewEncoder(w).Encode(status)
}
