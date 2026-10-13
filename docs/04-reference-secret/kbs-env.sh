#!/usr/bin/env bash
# Source from demo.sh to discover and export the KBS endpoint in its shell.
KBS_HOST=$(kubectl --context "$TRUSTEE_CONTEXT" get service trustee-kbs -n coco-trustee -o jsonpath='{.spec.clusterIP}') || return 1
KBS_PORT=$(kubectl --context "$TRUSTEE_CONTEXT" get service trustee-kbs -n coco-trustee -o jsonpath='{.spec.ports[?(@.name=="http")].port}') || return 1
if [[ -z "$KBS_HOST" || "$KBS_HOST" == None || -z "$KBS_PORT" ]]; then
    printf '%s\n' 'Cannot discover the Trustee KBS service endpoint.' >&2
    return 1
fi
[[ "$KBS_HOST" != *:* ]] || KBS_HOST="[$KBS_HOST]"
export KBS_HOST KBS_PORT
export KBS_URL=${KBS_URL:-http://$KBS_HOST:$KBS_PORT}
printf 'export KBS_HOST=%q\nexport KBS_PORT=%q\nexport KBS_URL=%q\n' "$KBS_HOST" "$KBS_PORT" "$KBS_URL"
