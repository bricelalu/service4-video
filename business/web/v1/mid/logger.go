package mid

import (
	"context"
	"net/http"

	"github.com/bricelalu/service/foundation/web"
	"go.uber.org/zap"
)

// Logger writes information about the request to the logs.
func Logger(log *zap.SugaredLogger) web.Middleware {
	m := func(handler web.Handler) web.Handler {

		h := func(ctx context.Context, w http.ResponseWriter, r *http.Request) error {

			path := r.URL.Path

			// LOG HERE - Started
			log.Infow("request started", "method", r.Method, "path", path,
				"remoteaddr", r.RemoteAddr)

			err := handler(ctx, w, r)

			// LOG HERE - Completed
			log.Info("request completed", "method", r.Method, "path", path,
				"remoteaddr", r.RemoteAddr)

			return err

		}

		return h

	}

	return m
}
