package testgrp

import (
	"context"
	"net/http"

	"github.com/bricelalu/service/foundation/web"
)

func Status(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	status := struct{ Status string }{Status: "ok"}

	return web.Respond(ctx, w, status, http.StatusOK)
}
