package testgrp

import (
	"context"
	"errors"
	"math/rand"
	"net/http"

	v1 "github.com/bricelalu/service/business/web/v1"
	"github.com/bricelalu/service/foundation/web"
)

func Status(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	if n := rand.Intn(100); n%2 == 0 {
		return v1.NewRequestError(errors.New("trusted error"), http.StatusBadRequest)
		//return errors.New("NON trusted error")
		//panic("ho no we panic")
	}

	status := struct{ Status string }{Status: "ok"}

	return web.Respond(ctx, w, status, http.StatusOK)
}
