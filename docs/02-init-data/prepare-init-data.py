#!/usr/bin/env python3
"""Refresh this stage's Init-Data from its guest policy."""
import base64
import gzip
from pathlib import Path
import re

stage = Path(__file__).resolve().parent
policy = (stage / "no-logs-exec-policy.rego").read_text()
initdata = 'version = "0.1.0"\nalgorithm = "sha384"\n[data]\n'
initdata += '"policy.rego" = ' + "'''\n" + policy + "'''\n"
encoded = base64.b64encode(gzip.compress(initdata.encode(), mtime=0)).decode()
manifest = stage / "nginx.yaml"
manifest.write_text(re.sub(
    r'(cc_init_data: )"[^"]*"',
    lambda match: match[1] + '"' + encoded + '"',
    manifest.read_text(),
))
