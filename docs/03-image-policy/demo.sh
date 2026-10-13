#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../demo-common.sh" "$@"
require_commands kubectl python3

p '# Stage 3: Init-Data permits one workload image digest.'
pe 'cat docs/03-image-policy/busybox-policy.rego'
pe 'python3 docs/03-image-policy/prepare-init-data.py'
p '# Both pods use identical Init-Data; only their names and image digests differ.'
pe 'diff -u docs/03-image-policy/busybox.yaml docs/03-image-policy/busybox-denied.yaml || test $? -eq 1'
pe 'kubectl apply -f docs/03-image-policy/busybox.yaml'
pe "kubectl wait -n default --for=jsonpath='{.status.phase}'=Succeeded pod/image-allowed --timeout=180s"
pe 'kubectl logs -n default image-allowed'
p '# The other image is rejected by the guest policy.'
pe 'kubectl apply -f docs/03-image-policy/busybox-denied.yaml'
expect_pod_rejection image-denied image
