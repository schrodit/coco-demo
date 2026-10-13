#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../demo-common.sh" "$@"
require_commands helm kubectl

p '# Stage 1: launch a simple Kata container.'
pe 'helm upgrade --install coco oci://ghcr.io/confidential-containers/charts/confidential-containers --namespace coco-system --create-namespace --wait --timeout 5m'
pe 'kubectl get pods -n coco-system'
pe 'kubectl get runtimeclasses'
pe 'cat docs/01-simple-kata-container/nginx.yaml'
pe 'kubectl apply -n default -f docs/01-simple-kata-container/nginx.yaml'
pe 'kubectl wait -n default --for=condition=Ready pod/nginx --timeout=180s'
pe 'kubectl logs -n default nginx'
pe "kubectl exec -n default nginx -- /bin/sh -c 'echo exec-allowed'"
pe 'sudo k0s ctr -n k8s.io containers list | grep kata'
p '# Exec is allowed. Continue with stage 2 to restrict access through the agent.'
