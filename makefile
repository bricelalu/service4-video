# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

# ==============================================================================
# CLASS NOTES
#
# Kind
# 	For full Kind v0.18 release notes: https://github.com/kubernetes-sigs/kind/releases/tag/v0.18.0
#
# RSA Keys
# 	To generate a private/public key PEM file.
# 	$ openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048
# 	$ openssl rsa -pubout -in private.pem -out public.pem
#
# OPA Playground
# 	https://play.openpolicyagent.org/
# 	https://academy.styra.com/
# 	https://www.openpolicyagent.org/docs/latest/policy-reference/

# ==============================================================================
# Define dependencies

GOLANG          := golang:1.20
ALPINE          := alpine:3.18
KIND            := kindest/node:v1.27.1
POSTGRES        := postgres:15.3
VAULT           := hashicorp/vault:1.13
ZIPKIN          := openzipkin/zipkin:2.24
TELEPRESENCE    := datawire/tel2:2.13.1

KIND_CLUSTER    := ardan-starter-cluster
NAMESPACE       := sales-system
APP             := sales
BASE_IMAGE_NAME := ardanlabs/service
SERVICE_NAME    := sales-api
#VERSION         := $(shell git rev-parse --short HEAD)
VERSION			:= 1.0
SERVICE_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME):$(VERSION)


load-images:
	docker pull $(GOLANG)
	docker pull $(ALPINE)
	docker pull $(KIND)
	docker pull $(POSTGRES)
	docker pull $(VAULT)
	docker pull $(ZIPKIN)
	docker pull $(TELEPRESENCE)

# ==============================================================================
# Building containers

all: service

service:
	docker build \
		-f zarf/docker/dockerfile.service \
		-t $(SERVICE_IMAGE) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.


run:
	go run app/services/sales-api/main.go | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

tidy:
	go mod tidy
	go mod vendor

# ==============================================================================
# Metrics and Tracing

metrics-local:
	expvarmon -ports="localhost:3499" -vars="build,requests,goroutines,errors,panics,mem:memstats.Alloc"

metrics-view:
	expvarmon -ports="sales-service.sales-system.svc.cluster.local:3499" -vars="build,requests,goroutines,errors,panics,mem:memstats.Alloc"

# ==============================================================================
# Running tests within the local computer
# go install honnef.co/go/tools/cmd/staticcheck@latest
# go install golang.org/x/vuln/cmd/govulncheck@latest

test:
	CGO_ENABLED=0 go test -count=1 ./...
	CGO_ENABLED=0 go vet ./...
	staticcheck -checks=all ./...
	govulncheck ./...

# ==============================================================================
# Running from within k8s/kind

up:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

	kind load docker-image $(TELEPRESENCE) --name $(KIND_CLUSTER)
	kind load docker-image $(POSTGRES) --name $(KIND_CLUSTER)
	telepresence --context=kind-$(KIND_CLUSTER) helm upgrade
	telepresence --context=kind-$(KIND_CLUSTER) connect

jwt:
	go run app/scratch/jwt/main.go

# http://sales-service.sales-system.svc.cluster.local:3499/debug/pprof
# curl -il http://sales-service.sales-system.svc.cluster.local:3499/debug/vars
# curl -il http://sales-service.sales-system.svc.cluster.local:3000/status
status:
	 curl -il http://sales-service.sales-system.svc.cluster.local:3000/status

auth:
	 curl -il http://sales-service.sales-system.svc.cluster.local:3000/auth

up-tel:
	telepresence --context=kind-$(KIND_CLUSTER) helm upgrade
	telepresence --context=kind-$(KIND_CLUSTER) connect

down-tel:
	telepresence quit -s

down-local:
	kind delete cluster --name $(KIND_CLUSTER)

down:
	telepresence quit -s
	kind delete cluster --name $(KIND_CLUSTER)

load:
	kind load docker-image $(SERVICE_IMAGE) --name $(KIND_CLUSTER)

apply:
	kustomize build zarf/k8s/dev/sales | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(APP) --for=condition=Ready

# ------------------------------------------------------------------------------

kube-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

restart:
	kubectl rollout restart deployment $(APP) --namespace=$(NAMESPACE)

update-restart: all load restart

update-apply: all load apply

# ------------------------------------------------------------------------------

logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(APP) --all-containers=true -f --tail=100 | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

describe-deployment:
	kubectl describe deployment --namespace=$(NAMESPACE) $(APP)

describe-pod:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(APP)

logs-init:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(APP) -f --tail=100 -c init-migrate

# ==============================================================================

load-test:
	hey -m GET -c 100 -n 10000 http://sales-service.sales-system.svc.cluster.local:3000/status