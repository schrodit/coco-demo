1. Install coco chart
```
helm upgrade --install coco oci://ghcr.io/confidential-containers/charts/confidential-containers \
  --namespace coco-system \
  --create-namespace
```
2. Check chart to be ready
```
kubectl get pods -n coco-system --watch
```

3. check runtime classes

4. deploy simple app
```
kubectl apply -f ./templates/00-nginx-dev.yaml
```

5. not secured: anyone can deploy anything. How to secure it
Policies

6. install trusteee: :warning: should never be in the same cluster --> secure env

```
helm upgrade --install trustee oci://ghcr.io/schrodit/charts/trustee:0.21.0 -n coco-trustee --create-namespace
```

7. set affirming policy
```
./kbs-client --url=http://10.98.43.15:8080 config --admin-token-file ./TRUSTEE_ADMIN.txt set-resource-policy --affirming
```

```
package policy
import rego.v1

default allow = false

allow if {
	input["submods"]["cpu0"]["ear.status"] == "affirming"
}
```

8. Policy for only allowed images

`templates/busybox-policy.rego` allows only the pinned BusyBox image from
`templates/02-busybox-secret.yaml`, plus the guest's built-in pause container
required for the pod sandbox. It blocks exec and policy replacement. This policy
requires a policy-enabled CoCo runtime with guest image pulling (`image_guest_pull`).
It applies to the annotated pod, not to every pod in the cluster.

Package the policy as [Init-Data](https://confidentialcontainers.org/docs/features/initdata/)
and deploy a BusyBox demo pod (run from the repository root):

```sh
initdata=$(
  {
    printf '%s\n' 'version = "0.1.0"' 'algorithm = "sha384"' '[data]' "\"policy.rego\" = '''"
    cat ./templates/busybox-policy.rego
    printf '%s\n' "'''"
  } | gzip -c | base64 | tr -d '\n'
)

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: busybox-policy-demo
  annotations:
    io.katacontainers.config.hypervisor.cc_init_data: "$initdata"
spec:
  runtimeClassName: kata-qemu-coco-dev
  restartPolicy: Never
  containers:
    - name: busybox
      image: docker.io/library/busybox@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e
      command: ["/bin/sh", "-c", "echo 'BusyBox allowed'; sleep 3600"]
EOF
```

The policy pins the digest; other images and unpinned BusyBox tags are denied.
To protect secret release against a host substituting a different policy, the
KBS resource policy must also require the expected Init-Data hash (see below).

9. Block logs and exec for nginx

`templates/no-logs-exec-policy.rego` denies exec, stdout/stderr reads, stdin writes,
and policy replacement while allowing container creation and pod lifecycle operations.
`templates/01-nginx-kbs.yaml` embeds this policy as gzip/base64 Init-Data and keeps
the existing KBS endpoint. It requires a policy-enabled CoCo runtime.

```sh
kubectl apply -f ./templates/01-nginx-kbs.yaml
kubectl wait --for=condition=Ready pod/nginx-kbs --timeout=120s
kubectl logs nginx-kbs
kubectl exec nginx-kbs -- /bin/sh -c 'echo exec-allowed'
```

The logs command should return no container output or report a policy denial;
the exec command should be denied. Blocking stream reads prevents the host from
collecting new stdout/stderr output, but does not erase previously collected logs.
Recreate an existing nginx-kbs pod to apply the new Init-Data.

After editing the policy, refresh the embedded annotation from the repository root:

```sh
python3 - <<'PY'
import base64
import gzip
from pathlib import Path
import re

policy = Path("templates/no-logs-exec-policy.rego").read_text()
initdata = 'version = "0.1.0"\nalgorithm = "sha384"\n[data]\n'
initdata += '"policy.rego" = ' + "'''\n" + policy + "'''\n"
encoded = base64.b64encode(gzip.compress(initdata.encode(), mtime=0)).decode()
manifest = Path("templates/01-nginx-kbs.yaml")
manifest.write_text(re.sub(
    r'(io\.katacontainers\.config\.hypervisor\.cc_init_data: )"[^"]*"',
    lambda match: match[1] + '"' + encoded + '"',
    manifest.read_text(),
))
PY
```

For attestation-bound enforcement, require the expected Init-Data hash in the KBS
resource policy as described below.

10. Use secrets

Use the BusyBox policy to fetch a disposable demo value from Trustee through a
[CoCo sealed secret](https://confidentialcontainers.org/docs/features/sealed-secrets/).
Kubernetes stores a signed pointer; the guest attests to KBS and unseals the value
into `PROTECTED_SECRET`. `templates/02-busybox-secret.yaml` includes both the
BusyBox policy Init-Data annotation and the KBS kernel parameter annotation.
The policy still blocks exec and other workload images; logs are allowed so this
demo prints the fetched value. Use only a disposable value for this example.

Requires `oras`, `kubectl`, `./kbs-client`, and the admin token from step 7.
Run the commands manually from the repository root, in the same terminal.
Continue only after each command succeeds. The KBS URL must be reachable from
both your shell and the guest. Keep the resource policy from step 7: secret
release requires an `affirming` result, which a simulated runtime may not satisfy.

**10a. Choose the endpoint and prepare a temporary working directory.**

Change the URL to match your KBS, then run these commands one at a time:

```sh
export KBS_URL=http://10.98.43.15:8080
SECRET_DEMO_DIR=$(mktemp -d)
```

**10b. Download the CLI and create signing keys.**

```sh
(cd "$SECRET_DEMO_DIR" && oras pull ghcr.io/confidential-containers/guest-components/secret-cli:latest)
chmod +x "$SECRET_DEMO_DIR/secret"
"$SECRET_DEMO_DIR/secret" keygen --kid busybox-demo --output-dir "$SECRET_DEMO_DIR/keys"
```

Check that `busybox-demo-private.json` and `busybox-demo-public.json` were created
in the working directory's `keys` folder. Only upload the public key to KBS.

**10c. Create and upload the demo value.**

```sh
printf '%s' 'busybox-demo-secret-value' > "$SECRET_DEMO_DIR/value"
```

```sh
./kbs-client --url "$KBS_URL" config --admin-token-file ./TRUSTEE_ADMIN.txt \
  set-resource --path default/test_secrets/busybox \
  --resource-file "$SECRET_DEMO_DIR/value"
```

**10d. Upload the public verification key.**

```sh
./kbs-client --url "$KBS_URL" config --admin-token-file ./TRUSTEE_ADMIN.txt \
  set-resource --path default/test_signing/busybox_public \
  --resource-file "$SECRET_DEMO_DIR/keys/busybox-demo-public.json"
```

**10e. Generate a signed pointer to the secret.**

```sh
"$SECRET_DEMO_DIR/secret" seal \
  --signing-kid kbs:///default/test_signing/busybox_public \
  --signing-jwk-path "./keys/busybox-demo-private.json" \
  vault --resource-uri kbs:///default/test_secrets/busybox --provider kbs
```

Copy only the output string beginning with `sealed.`, excluding warnings. Paste
it in place of `PASTE_SEALED_POINTER_HERE` in the next command.

**10f. Store the sealed pointer in Kubernetes.**

```sh
kubectl create secret generic sealed-secret -n default \
  --from-literal='secret=PASTE_SEALED_POINTER_HERE'
```

If the Secret already exists from a previous demo, run
`kubectl delete secret sealed-secret -n default` first, then recreate it.

**10g. Package the BusyBox policy as Init-Data.**

Run these commands one at a time to create the header, append the policy, and
close the TOML multiline string:

```sh
printf '%s\n' 'version = "0.1.0"' 'algorithm = "sha384"' '[data]' "\"policy.rego\" = '''" > "$SECRET_DEMO_DIR/initdata.toml"
```

```sh
cat ./templates/busybox-policy.rego >> "$SECRET_DEMO_DIR/initdata.toml"
```

```sh
printf '%s\n' "'''" >> "$SECRET_DEMO_DIR/initdata.toml"
```

Inspect the file before encoding it:

```sh
cat "$SECRET_DEMO_DIR/initdata.toml"
```

Compress and encode the Init-Data. Copy the complete output line:

```sh
gzip -c "$SECRET_DEMO_DIR/initdata.toml" | base64 | tr -d '\n'
```

**10h. Edit the annotations by hand.**

Open `templates/02-busybox-secret.yaml` in your editor. Replace the existing
`cc_init_data` value with the base64 output from 10g, on one line inside quotes.
Set the KBS URL in `kernel_params` to the address chosen in 10a:

```yaml
metadata:
  annotations:
    io.katacontainers.config.hypervisor.cc_init_data: "PASTE_BASE64_INIT_DATA_HERE"
    io.containerd.cri.runtime-handler: kata-qemu-coco-dev
    io.katacontainers.config.hypervisor.kernel_params: "agent.aa_kbc_params=cc_kbc::http://10.98.43.15:8080"
```

Keep `spec.runtimeClassName: kata-qemu-coco-dev` and the pinned BusyBox image.
The environment variable must reference Secret `sealed-secret`, key `secret`,
matching 10f. Save the file. Repeat 10g–10h after editing the BusyBox policy.

**10i. Deploy the pod and read the fetched value.**

Remove an existing demo pod so the new annotations and Secret take effect:

```sh
kubectl delete pod sealed-secret-pod -n default --ignore-not-found
```

```sh
kubectl apply -f ./templates/02-busybox-secret.yaml
```

```sh
kubectl wait -n default --for=jsonpath='{.status.phase}'=Succeeded \
  pod/sealed-secret-pod --timeout=180s
```

```sh
kubectl logs -n default sealed-secret-pod
```

Expected output: `busybox-demo-secret-value`. If the pod does not complete,
inspect it with `kubectl describe pod -n default sealed-secret-pod` before
continuing. Unsealing happens inside the guest; BusyBox needs no KBS client binary
and exec remains denied. For attestation-bound policy enforcement, also require
the expected Init-Data hash in the KBS resource policy as described below.

#### Kata Agent Policy

Which operations the agent can perform (create containers, exec into pods, etc.)

Confidential Containers run inside a TEE, but they still interact with the Kubernetes control plane. A malicious or compromised control plane could attempt to:

Execute arbitrary commands in your container (kubectl exec)
Launch unauthorized container images
Extract secrets or sensitive data

Example use cases:

- Prevent kubectl exec into production pods
- Restrict which container images can be launched
- Control which commands can be executed

```
package agent_policy
import rego.v1

default CreateContainerRequest := false
default ExecProcessRequest := false

# Only allow specific image digests
CreateContainerRequest if {
	input.storages[0].source == "docker.io/library/nginx@sha256:abc123..."
}
```

#### KBS Resource Policy
KBS Resource Policy

Example use cases:
- Verify the workload is using a specific kata agent policy (via Init-Data hash)
- Only release database credentials to attesting TDX guests
- Require specific trust levels (affirming vs contraindicated)
- Different secrets for different platforms (TDX vs SNP)

```
package policy
import rego.v1

default allow = false

# Only release secrets to workloads with the expected Init-Data hash
allow if {
	input["submods"]["cpu0"]["ear.status"] == "affirming"
	# Verify the specific Init-Data hash (includes kata agent policy + config)
	input["submods"]["cpu0"]["ear.veraison.annotated-evidence"]["init_data"] == "expected-hash-here"
}
```

#### Attestation Service Policy
How hardware evidence is evaluated (what TCB is acceptable)

Example use cases:
- Define acceptable firmware versions
- Specify required security levels for different workloads
- Map hardware measurements to trust claims
