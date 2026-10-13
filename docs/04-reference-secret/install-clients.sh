#!/usr/bin/env bash
# Source from demo.sh to install the clients and export their executable paths.
KBS_CLIENT_IMAGE=${KBS_CLIENT_IMAGE:-ghcr.io/confidential-containers/staged-images/kbs-client:latest}
SECRET_CLI_IMAGE=${SECRET_CLI_IMAGE:-ghcr.io/confidential-containers/guest-components/secret-cli:latest}
KBS_CLIENT=$SECRET_DEMO_ROOT/kbs-client/kbs-client
SECRET_TOOL=$SECRET_DEMO_ROOT/secret-cli/target/x86_64-unknown-linux-musl/release/secret

mkdir -p "$SECRET_DEMO_ROOT/kbs-client" "$SECRET_DEMO_ROOT/secret-cli" || return 1
# Keep successful installation quiet; display the log if a download fails.
if ! (
    (cd "$SECRET_DEMO_ROOT/kbs-client" && oras pull "$KBS_CLIENT_IMAGE") &&
    (cd "$SECRET_DEMO_ROOT/secret-cli" && oras pull --platform linux/amd64 "$SECRET_CLI_IMAGE") &&
    chmod +x "$KBS_CLIENT" "$SECRET_TOOL"
) > "$SECRET_DEMO_ROOT/install-clients.log" 2>&1; then
    cat "$SECRET_DEMO_ROOT/install-clients.log" >&2
    return 1
fi

export KBS_CLIENT SECRET_TOOL
printf 'export KBS_CLIENT=%q\nexport SECRET_TOOL=%q\n' "$KBS_CLIENT" "$SECRET_TOOL"
