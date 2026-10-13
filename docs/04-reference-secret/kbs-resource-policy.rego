package policy

import rego.v1

# Dev-runtime test only: sample Init-Data is supplied by the client, not hardware-verified.
# Use kbs-resource-policy-hardware.rego for verified TDX binding.
default allow := false

# Base64 SHA-384 of the exact, uncompressed Init-Data TOML (sample verifier encoding).
expected_init_data := "e5nxd9RRD2XPCt+exXq8V9sqI+YyEsOt6ptmQUmPXpsdnfN+DCORtU/2Qnz3sJMJ"

# The public verification key is not confidential.
allow if {
    data.plugin == "resource"
    data["resource-path"] == ["default", "test_signing", "busybox_public"]
}

# Missing or different Init-Data is denied. Enabling exec in the second
# guest policy changes its hash, so KBS denies that pod the secret.
allow if {
    data.plugin == "resource"
    data["resource-path"] == ["default", "test_secrets", "busybox"]
    evidence := input.submods.cpu0["ear.veraison.annotated-evidence"]
    is_object(evidence.sample)
    evidence.init_data == expected_init_data
}
