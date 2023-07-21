package handlers

import (
	"net/http"
	"os"

	"github.com/bricelalu/service/app/services/sales-api/handlers/v1/testgrp"
	"github.com/bricelalu/service/business/web/auth"
	"github.com/bricelalu/service/business/web/v1/mid"
	"github.com/bricelalu/service/foundation/web"
	"go.uber.org/zap"
)

// APIMuxConfig contains all the mandatory systems required by handlers.
type APIMuxConfig struct {
	Shutdown chan os.Signal
	Log      *zap.SugaredLogger
	Auth     *auth.Auth
}

// APIMux constructs a http.Handler with all application routes defined.
func APIMux(cfg APIMuxConfig) *web.App {
	// Panics would be at the very end of this food chain
	// Because it should be the first function that wrap status.
	app := web.NewApp(cfg.Shutdown, mid.Logger(cfg.Log), mid.Errors(cfg.Log), mid.Metrics(), mid.Panics())

	app.Handle(http.MethodGet, "/status", testgrp.Status)

	app.Handle(http.MethodGet, "/auth", testgrp.Status, mid.Authenticate(cfg.Auth))

	return app
}
