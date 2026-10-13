#!/usr/bin/env bash
# Shared setup for the stage scripts; source from Bash.

DEMO_REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DEMO_REPO_ROOT" || exit 1

DEMO_MAGIC_PATH=${DEMO_MAGIC_PATH:-$DEMO_REPO_ROOT/modules/demo-magic/demo-magic.sh}
if [[ ! -f "$DEMO_MAGIC_PATH" ]]; then
    printf 'Cannot find demo-magic: %s\n' "$DEMO_MAGIC_PATH" >&2
    printf '%s\n' 'Run git submodule update --init modules/demo-magic; see docs/README.md.' >&2
    exit 1
fi

# Keep upstream display options, including -d to disable simulated typing.
source "$DEMO_MAGIC_PATH" "$@"
# All stages print and execute without waiting for Enter.
NO_WAIT=true
set -eo pipefail

DEMO_PROMPT='$ '

# Upstream pe masks command failures with terminal cleanup. Preserve the result
# so a failed setup command stops the demo before dependent commands execute.
pe() {
    p "$1"
    eval "$1"
}

require_commands() {
    local tool
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Required command is missing: %s\n' "$tool" >&2
            exit 1
        fi
    done
}

# A failed kubectl command alone is not proof of policy enforcement.
expect_policy_denial() {
    local output
    p "$1"
    if output=$(eval "$1" 2>&1); then
        printf '%s\n' "$output" >&2
        printf '%s\n' 'Expected a policy denial, but the command succeeded.' >&2
        return 1
    fi
    printf '%s\n' "$output"
    if ! grep -Eiq 'policy|not allowed|denied by.*agent' <<< "$output"; then
        printf '%s\n' 'Command failed without a recognizable policy denial; inspect the runtime.' >&2
        return 1
    fi
}

# Kubernetes reports guest failures asynchronously. Require a matching rejection,
# rather than treating a timeout, scheduling issue, or image-pull error as proof.
expect_pod_rejection() {
    local pod=$1 kind=$2 output phase pattern deadline=$((SECONDS + 180))
    if [[ "$kind" == image ]]; then
        pattern='(CreateContainerRequest.*(policy|denied|not allowed)|(policy|denied|not allowed).*CreateContainerRequest)'
    else
        pattern='((secret|unseal|resource|kbs).*(403|forbidden|unauthorized|denied)|(403|forbidden|unauthorized|denied).*(secret|unseal|resource|kbs))'
    fi
    while (( SECONDS < deadline )); do
        phase=$(kubectl get pod -n default "$pod" -o jsonpath='{.status.phase}') || return 1
        output=$(kubectl get pod -n default "$pod" -o jsonpath='{.status.containerStatuses[*].state.waiting.message}{.status.message}') || return 1
        output+=$'\n'$(kubectl get events -n default --field-selector "involvedObject.name=$pod,involvedObject.kind=Pod" -o jsonpath='{range .items[*]}{.message}{"\n"}{end}') || return 1
        if [[ "$phase" == Running || "$phase" == Succeeded ]]; then
            printf 'Expected rejection, but %s reached %s.\n' "$pod" "$phase" >&2
            return 1
        fi
        if grep -Eiq "$pattern" <<< "$output"; then
            printf '%s\n' "$output"
            return 0
        fi
        sleep 3
    done
    printf '%s\n' "$output" >&2
    printf 'No recognizable %s rejection for %s; inspect guest/runtime and KBS logs.\n' "$kind" "$pod" >&2
    return 1
}
