# 3. Allow one image digest

Run `make demo3` (or `bash docs/03-image-policy/demo.sh`). Requires Python 3,
`kubectl`, and a policy-enabled `kata-qemu-coco-dev` runtime with guest image
pulling, as installed in the preceding stages. Trustee is not needed.

The [guest policy](busybox-policy.rego) permits one BusyBox image digest and the
guest's built-in sandbox pause image. It is packaged in each pod's Init-Data.

- [busybox.yaml](busybox.yaml) uses the permitted digest and prints `Image allowed by guest policy`.
- [busybox-denied.yaml](busybox-denied.yaml) uses a different digest. The guest rejects its `CreateContainerRequest`.

Both pods have identical Init-Data. Their only differences are pod name and image
digest, making this an image-policy demonstration without secrets.

The presenter regenerates Init-Data, shows the manifest diff, verifies that the
allowed pod completes, then waits for an explicit policy rejection in the denied
pod's events. A timeout or image-pull failure does not count as a policy denial.
If the runtime only reports the rejection in guest logs, inspect those logs.

Manual commands:

```sh
python3 docs/03-image-policy/prepare-init-data.py
kubectl apply -f docs/03-image-policy/busybox.yaml
kubectl wait -n default --for=jsonpath='{.status.phase}'=Succeeded pod/image-allowed --timeout=180s
kubectl logs -n default image-allowed
kubectl apply -f docs/03-image-policy/busybox-denied.yaml
kubectl describe pod -n default image-denied
```

Repeat the packaging step whenever the policy changes. The policy compares the
`image_guest_pull` storage source to the pinned digest; use guest image pulling
for this demo. Run `make cleanup` before rerunning with changed specifications.
Continue with [demo4: secret release](../04-reference-secret/README.md).
