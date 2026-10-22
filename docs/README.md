# Demo stages

Run commands from the repository root. Each stage keeps its manifests, policies,
commands, and expected results together.

1. [Simple Kata container](01-simple-kata-container/README.md): install CoCo and run nginx.
2. [Init-Data: do not allow admin access](02-init-data/README.md): deny logs, exec, and policy replacement inside the guest.
3. [Allow one image digest](03-image-policy/README.md): identical Init-Data permits one image and rejects another, without secrets.
4. [Secret release bound to Init-Data](04-reference-secret/README.md): identical images request the same secret; enabling exec changes Init-Data and KBS denies the second pod.

All stages default to `kata-qemu-coco-dev`. Stages 3 and 4 require a policy-enabled
runtime with guest image pulling. Stage 4's dev KBS policy checks the approved
Init-Data hash in sample claims, which are not hardware-verified. Use only the
disposable demo secret. See [dev versus hardware](04-reference-secret/README.md#dev-versus-hardware)
for the verified TDX variant.

## Run with demo-magic

The presenter scripts use [demo-magic](https://github.com/paxtonhare/demo-magic),
included at `modules/demo-magic`. Initialize it from the repository root:

```sh
git submodule update --init modules/demo-magic
make demo1
make demo2
make demo3
make demo4
```

Set `DEMO_MAGIC_PATH` to use another copy. Each command is displayed and waits
for Enter before executing against your selected Kubernetes context. Automatic
execution options (`-n` and `-w`) are overridden so every stage requires Enter.
Install `pv` for simulated typing, or use `DEMO_ARGS="-d"` to disable typing.

Complete each stage's prerequisites first. Stage 1 installs CoCo; later stages
refresh their embedded Init-Data. Stage 3 verifies the allowed image completes
and waits for the other image's policy rejection. Stage 4 provisions Trustee and
its own secret, verifies retrieval in the approved pod, then
checks the modified pod's secret rejection. It runs independently of demo3.
Scripts stop on unexpected failures; timeouts alone do not prove enforcement.

Stage 4 downloads tools and stores credentials, signing keys, and generated
manifests in Git-ignored `.demo/demo4/`. Set `TRUSTEE_CONTEXT` for a different
Trustee cluster and `KBS_URL` for an endpoint reachable from the shell and guest.
See [stage 4 setup](04-reference-secret/README.md#automated-presenter-setup).

Run `make cleanup` before rerunning with changed pod specifications. Cleanup
removes the demo pods and Kubernetes Secret; it leaves Trustee and local tools,
credentials, and keys in place.
