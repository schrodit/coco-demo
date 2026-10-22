SHELL := /bin/sh
.DEFAULT_GOAL := trustee-build

HELM ?= helm
TRUSTEE_DIR ?= modules/trustee
CHART_DIR ?= $(TRUSTEE_DIR)/deployment/helm-chart
DIST_DIR ?= dist
# Destination namespace only; Helm appends the chart name and version.
OCI_REGISTRY ?= oci://ghcr.io/schrodit/charts
DEMO_ARGS ?=

.PHONY: help demo1 demo2 demo3 demo4 cleanup trustee-check-chart trustee-check-registry trustee-dependencies trustee-lint trustee-build trustee-push

help:
	@printf '%s\n' \
		'make demo1                          Start the simple Kata container demo' \
		'make demo2                          Start the Init-Data demo' \
		'make demo3                          Show allowed and denied image digests' \
		'make demo4                          Show secret release bound to Init-Data' \
		'make cleanup                        Delete all demo pods and the demo Kubernetes secret' \
		'Demos wait for Enter before execution; add DEMO_ARGS="-d" to disable typing' \
		'make trustee-build                  Build dependencies, lint, and package the Trustee chart' \
		'make trustee-lint                   Build dependencies and lint the Trustee chart' \
		'make trustee-push OCI_REGISTRY=oci://HOST/NAMESPACE  Build and upload the chart' \
		'Overrides: HELM, TRUSTEE_DIR, CHART_DIR, DIST_DIR'

demo1:
	bash docs/01-simple-kata-container/demo.sh $(DEMO_ARGS)

demo2:
	bash docs/02-init-data/demo.sh $(DEMO_ARGS)

demo3:
	bash docs/03-image-policy/demo.sh $(DEMO_ARGS)

demo4:
	bash docs/04-reference-secret/demo.sh $(DEMO_ARGS)

cleanup:
	kubectl delete pod -n default nginx nginx-no-admin image-allowed image-denied sealed-secret-pod sealed-secret-denied --ignore-not-found
	kubectl delete secret -n default sealed-secret --ignore-not-found

trustee-check-chart:
	@command -v "$(HELM)" >/dev/null 2>&1 || { echo 'Helm is required (Helm 3.8+ or 4).' >&2; exit 1; }
	@test -f "$(CHART_DIR)/Chart.yaml" || { \
		echo 'Trustee chart not found at $(CHART_DIR). Check out the Trustee repository or set TRUSTEE_DIR/CHART_DIR.' >&2; \
		exit 1; \
	}

trustee-check-registry:
	@case "$(OCI_REGISTRY)" in \
		oci://?*) ;; \
		*) echo 'Set OCI_REGISTRY to an OCI namespace, e.g. oci://ghcr.io/schrodit/charts (without chart name or tag).' >&2; exit 1 ;; \
	esac

trustee-dependencies: trustee-check-chart
	$(HELM) dependency build "$(CHART_DIR)" --skip-refresh

trustee-lint: trustee-dependencies
	$(HELM) lint "$(CHART_DIR)"

trustee-build: trustee-lint
	mkdir -p "$(DIST_DIR)"
	$(HELM) package "$(CHART_DIR)" --destination "$(DIST_DIR)"

trustee-push: trustee-check-registry
	$(MAKE) trustee-build
	@set -eu; \
	metadata="$$( $(HELM) show chart "$(CHART_DIR)" )"; \
	name="$$(printf '%s\n' "$$metadata" | awk '/^name:/ { print $$2 }')"; \
	version="$$(printf '%s\n' "$$metadata" | awk '/^version:/ { print $$2 }')"; \
	$(HELM) push "$(DIST_DIR)/$$name-$$version.tgz" "$(OCI_REGISTRY)"
