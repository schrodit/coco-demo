# 2. Init-Data: do not allow admin access

Presenter script: `bash docs/02-init-data/demo.sh`.
See [demo-magic setup and options](../README.md#run-with-demo-magic).

[nginx.yaml](nginx.yaml) embeds [no-logs-exec-policy.rego](no-logs-exec-policy.rego)
as gzip/base64 Init-Data. The guest denies exec, stdout/stderr reads, stdin writes,
policy replacement, and requests to bypass policy failures. Container creation
and normal lifecycle operations remain allowed. Requires a policy-enabled runtime.

This restricts host access through the Kata agent. It does not remove Kubernetes
administrator permissions, prevent pod deletion, or restrict which images may run.

Deploy and check the restrictions:

```sh
kubectl apply -f docs/02-init-data/nginx.yaml
kubectl wait -n default --for=condition=Ready pod/nginx-no-admin --timeout=180s
kubectl logs -n default nginx-no-admin
kubectl exec -n default nginx-no-admin -- /bin/sh -c 'echo exec-allowed'
```

Expected: logs return no container output or a policy denial; exec is denied.
Blocking reads does not erase logs collected previously.

After changing the Rego policy, refresh its embedded annotation before recreating
the pod. Run `make cleanup` to remove existing demo resources, then run this
from the repository root:

```sh
python3 docs/02-init-data/prepare-init-data.py
```

Cleanup:

```sh
make cleanup
```

Continue with [stage 3](../03-image-policy/README.md) to allow one image digest
and reject another using the policy embedded in Init-Data.
