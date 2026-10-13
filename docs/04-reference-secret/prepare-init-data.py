#!/usr/bin/env python3
"""Package both guest policies; approve only the policy that denies exec."""
import base64
import gzip
import hashlib
from pathlib import Path
import re

stage = Path(__file__).resolve().parent

def payload(policy_name):
    policy = (stage / policy_name).read_text()
    return ('version = "0.1.0"\nalgorithm = "sha384"\n[data]\n'
            + '"policy.rego" = ' + "'''\n" + policy + "'''\n").encode()

for name, policy_name in (
    ("busybox-secret.yaml", "busybox-policy.rego"),
    ("busybox-secret-denied.yaml", "busybox-policy-exec.rego"),
):
    encoded = base64.b64encode(gzip.compress(payload(policy_name), mtime=0)).decode()
    manifest = stage / name
    manifest.write_text(re.sub(
        r'(cc_init_data: )"[^"]*"',
        lambda match: match[1] + '"' + encoded + '"',
        manifest.read_text(),
    ))

approved_digest = hashlib.sha384(payload("busybox-policy.rego")).digest()
for name, digest in (
    ("kbs-resource-policy.rego", base64.b64encode(approved_digest).decode()),
    ("kbs-resource-policy-hardware.rego", approved_digest.hex()),
):
    resource_policy = stage / name
    resource_policy.write_text(re.sub(
        r'expected_init_data := "[^"]*"',
        lambda _: 'expected_init_data := "' + digest + '"',
        resource_policy.read_text(),
    ))
    print(name, 'approved Init-Data SHA-384:', digest)
