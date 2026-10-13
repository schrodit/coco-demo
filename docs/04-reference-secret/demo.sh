#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../demo-common.sh" "$@"
require_commands kubectl helm oras python3 yq base64

SECRET_DEMO_ROOT=$DEMO_REPO_ROOT/.demo/demo4
ADMIN_TOKEN_FILE=$SECRET_DEMO_ROOT/TRUSTEE_ADMIN.txt
TRUSTEE_CONTEXT=${TRUSTEE_CONTEXT:-$(kubectl config current-context)}
KBS_RESOURCE_POLICY=${KBS_RESOURCE_POLICY:-docs/04-reference-secret/kbs-resource-policy.rego}
if [[ ! -r "$KBS_RESOURCE_POLICY" ]]; then
    printf 'Cannot read KBS_RESOURCE_POLICY: %s\n' "$KBS_RESOURCE_POLICY" >&2
    exit 1
fi

p '# Stage 4: release a sealed secret to a guest with the approved Init-Data.'
umask 077
p '# Install Trustee to verify attestation and serve the demo secret.'
pe 'helm --kube-context "$TRUSTEE_CONTEXT" upgrade --install trustee oci://ghcr.io/schrodit/charts/trustee:0.21.0 -n coco-trustee --create-namespace --wait --timeout 5m'
p '# Read its API address and save the admin token for provisioning.'
pe 'mkdir -p "$SECRET_DEMO_ROOT" && kubectl --context "$TRUSTEE_CONTEXT" get secret trustee-bootstrap-user-keys -n coco-trustee -o jsonpath="{.data.KBS_ADMIN_TOKEN}" | base64 --decode > "$ADMIN_TOKEN_FILE"'
test -s "$ADMIN_TOKEN_FILE" || { printf '%s\n' 'Trustee admin token is empty.' >&2; exit 1; }
source docs/04-reference-secret/kbs-env.sh

source docs/04-reference-secret/install-clients.sh

p '# Create a signing key for the sealed reference and upload only its public key.'
pe 'SECRET_DEMO_DIR=$(mktemp -d "$SECRET_DEMO_ROOT/run.XXXXXX")'
printf 'Signing keys, demo value, and generated manifests: %s\n' "$SECRET_DEMO_DIR"
pe 'mkdir -p "$SECRET_DEMO_DIR/keys" && "$SECRET_TOOL" keygen --kid busybox-demo --output-dir "$SECRET_DEMO_DIR/keys"'
pe "printf '%s' 'busybox-demo-secret-value' > \"\$SECRET_DEMO_DIR/value\""
pe '"$KBS_CLIENT" --url "$KBS_URL" config --admin-token-file "$ADMIN_TOKEN_FILE" set-resource --path default/test_secrets/busybox --resource-file "$SECRET_DEMO_DIR/value"'
pe '"$KBS_CLIENT" --url "$KBS_URL" config --admin-token-file "$ADMIN_TOKEN_FILE" set-resource --path default/test_signing/busybox_public --resource-file "$SECRET_DEMO_DIR/keys/busybox-demo-public.json"'
p '# Sign a pointer to the KBS secret. Kubernetes stores the pointer, not the value.'
pe '"$SECRET_TOOL" seal --signing-kid kbs:///default/test_signing/busybox_public --signing-jwk-path "$SECRET_DEMO_DIR/keys/busybox-demo-private.json" vault --resource-uri kbs:///default/test_secrets/busybox --provider kbs > "$SECRET_DEMO_DIR/seal-output"'
# Accept one complete sealed-pointer line; warnings are not part of the pointer.
SEALED_POINTER=$(python3 - "$SECRET_DEMO_DIR/seal-output" <<'PY'
from pathlib import Path
import sys

pointers = [line.strip() for line in Path(sys.argv[1]).read_text().splitlines()
            if line.strip().startswith("sealed.") and len(line.strip().split()) == 1]
if len(pointers) != 1:
    raise SystemExit("Expected exactly one sealed pointer in secret-cli output")
print(pointers[0])
PY
)
pe 'kubectl create secret generic sealed-secret -n default --from-literal="secret=$SEALED_POINTER" --dry-run=client -o yaml | kubectl apply -f -'
p '# Package the approved guest policy as Init-Data.'
pe 'cat docs/04-reference-secret/busybox-policy.rego'
pe 'python3 docs/04-reference-secret/prepare-init-data.py'
pe 'yq '\''.metadata.annotations."io.katacontainers.config.hypervisor.kernel_params" = "agent.aa_kbc_params=cc_kbc::" + strenv(KBS_URL)'\'' docs/04-reference-secret/busybox-secret.yaml > "$SECRET_DEMO_DIR/busybox-secret.yaml"'
pe 'yq '\''.metadata.annotations."io.katacontainers.config.hypervisor.kernel_params" = "agent.aa_kbc_params=cc_kbc::" + strenv(KBS_URL)'\'' docs/04-reference-secret/busybox-secret-denied.yaml > "$SECRET_DEMO_DIR/busybox-secret-denied.yaml"'
p '# KBS releases the secret only for this Init-Data hash; sample evidence is for testing.'
pe 'cat "$KBS_RESOURCE_POLICY"'
p '# Replace the KBS resource policy with this demo policy.'
pe '"$KBS_CLIENT" --url "$KBS_URL" config --admin-token-file "$ADMIN_TOKEN_FILE" set-resource-policy --policy-file "$KBS_RESOURCE_POLICY"'

p '# Start the approved pod. The guest unseals the pointer before the container starts.'
pe 'kubectl apply -f "$SECRET_DEMO_DIR/busybox-secret.yaml"'
pe 'kubectl wait -n default --for=condition=Ready pod/sealed-secret-pod --timeout=180s'
p 'kubectl logs -n default sealed-secret-pod'
secret_output=$(kubectl logs -n default sealed-secret-pod)
printf '%s\n' "$secret_output"
if [[ "$secret_output" != 'busybox-demo-secret-value' ]]; then
    printf '%s\n' 'The allowed pod did not return the expected demo value.' >&2
    exit 1
fi

p '# The approved pod fetched the secret successfully.'
p '# Compare the guest policies: the denied variant enables exec.'
pe 'diff -u docs/04-reference-secret/busybox-policy.rego docs/04-reference-secret/busybox-policy-exec.rego || test $? -eq 1'
p '# Same image and secret reference; enabling exec changes the Init-Data hash.'
pe 'kubectl apply -f "$SECRET_DEMO_DIR/busybox-secret-denied.yaml"'
expect_pod_rejection sealed-secret-denied secret
p '# KBS rejected the changed Init-Data. The denied container never starts.'
