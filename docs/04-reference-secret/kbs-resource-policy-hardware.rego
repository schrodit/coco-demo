package policy

import rego.v1

default allow := false

# SHA-384 of the exact, uncompressed Init-Data TOML; see this stage's README.
# This example uses verified TDX Init-Data claims in a Trustee EAR token.
expected_init_data := "7b99f177d4510f65cf0adf9ec57abc57db2a23e63212c3adea9b6641498f5e9b1d9df37e0c2391b54ff6427cf7b09309"

# The verification key is public; the private signing key never goes to KBS.
allow if {
    data.plugin == "resource"
    data["resource-path"] == ["default", "test_signing", "busybox_public"]
}

# Release the single demo secret only to the approved guest policy.
allow if {
    data.plugin == "resource"
    data["resource-path"] == ["default", "test_secrets", "busybox"]
    regex.match("^[0-9a-f]{96}$", expected_init_data)
    cpu := input.submods.cpu0
    cpu["ear.status"] == "affirming"
    evidence := cpu["ear.veraison.annotated-evidence"]
    is_object(evidence.tdx)
    evidence.init_data == expected_init_data
}
