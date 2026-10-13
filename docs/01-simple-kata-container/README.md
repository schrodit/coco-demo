# 1. Simple Kata container

Presenter script: `bash docs/01-simple-kata-container/demo.sh`.
See [demo-magic setup and options](../README.md#run-with-demo-magic).

Install Confidential Containers and wait for its components to be ready:

```sh
helm upgrade --install coco oci://ghcr.io/confidential-containers/charts/confidential-containers \
  --namespace coco-system --create-namespace
kubectl get pods -n coco-system --watch
```

Stop watching once the components are ready. Inspect the runtime classes:

```sh
kubectl get runtimeclasses
```

[nginx.yaml](nginx.yaml) selects `kata-qemu-coco-dev`. Update both the runtime
annotation and `runtimeClassName` if your installation uses a different name.

```sh
kubectl apply -n default -f docs/01-simple-kata-container/nginx.yaml
kubectl wait -n default --for=condition=Ready pod/nginx --timeout=180s
kubectl logs -n default nginx
kubectl exec -n default nginx -- /bin/sh -c 'echo exec-allowed'
```

On the k0s node running the pod, list Kata containers:

```sh
sudo k0s ctr -n k8s.io containers list | grep kata
```

Expected: nginx runs inside Kata and exec prints `exec-allowed`. This pod has no
guest policy restricting administrative access. Continue with
[stage 2](../02-init-data/README.md) to block that access.

Cleanup:

```sh
kubectl delete pod -n default nginx --ignore-not-found
```
