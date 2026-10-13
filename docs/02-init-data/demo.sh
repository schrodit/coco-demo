#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../demo-common.sh" "$@"
require_commands kubectl python3 yq base64 gzip

p '# Stage 2: protect the container from administrative agent access.'
pe 'cat docs/02-init-data/no-logs-exec-policy.rego'
pe 'python3 docs/02-init-data/prepare-init-data.py'
pe 'cat docs/02-init-data/nginx.yaml'
pe 'yq -r '\''.metadata.annotations."io.katacontainers.config.hypervisor.cc_init_data"'\'' docs/02-init-data/nginx.yaml | base64 --decode | gzip --decompress'
pe 'kubectl apply -f docs/02-init-data/nginx.yaml'
pe 'kubectl wait -n default --for=condition=Ready pod/nginx-no-admin --timeout=180s'

p '# Logs should be empty or denied; exec must be denied.'
# Some runtimes return success with empty output when stream reads are blocked.
p 'kubectl logs -n default nginx-no-admin'
logs_status=0
logs_output=$(kubectl logs -n default nginx-no-admin 2>&1) || logs_status=$?
printf '%s\n' "$logs_output"
if [[ -n "$logs_output" ]]; then
    if [[ "$logs_status" -eq 0 ]] || ! grep -Eiq 'policy|not allowed|denied by.*agent' <<< "$logs_output"; then
        printf '%s\n' 'Unexpected logs result; inspect whether the guest policy is enforced.' >&2
        exit 1
    fi
elif [[ "$logs_status" -ne 0 ]]; then
    printf '%s\n' 'Logs failed without a policy error; inspect the runtime.' >&2
    exit 1
fi
expect_policy_denial "kubectl exec -n default nginx-no-admin -- /bin/sh -c 'echo exec-allowed'"
p '# The guest blocks logs and exec. Stage 3 adds an image allowlist.'
