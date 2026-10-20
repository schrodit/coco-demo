# coco-demo

## Demo walkthrough

Follow the [four stages in docs](docs/README.md). Each stage contains its
templates and commands:

1. [Simple Kata container](docs/01-simple-kata-container/README.md)
2. [Init-Data: do not allow admin access](docs/02-init-data/README.md)
3. [Allow one image digest](docs/03-image-policy/README.md)
4. [Secret release bound to Init-Data](docs/04-reference-secret/README.md)

## Prerequisite Tools
#### KataContainer GenPolicy
```bash
VERSION=4.2.0
mkdir -p kata-tools-artifacts
curl -fsSL "https://github.com/kata-containers/kata-containers/releases/download/${VERSION}/kata-tools-static-${VERSION}-amd64.tar.zst" \
  --output kata-tools-artifacts/kata-tools-static.tar.zst
tar xf ./kata-tools-artifacts/kata-tools-static.tar.zst -C ./kata-tools-artifacts
sudo install -o root -g root -m 0755 ./kata-tools-artifacts/opt/kata/bin/genpolicy /opt/kata/bin/genpolicy
sudo cp -R ./kata-tools-artifacts/opt/kata/share/defaults/kata-containers/* /opt/kata/share/defaults/kata-containers
rm -rf kata-tools-artifacts
```

## Trustee Helm chart

The Trustee Helm chart is served through this repository's
[GitHub Container Registry package](https://github.com/users/schrodit/packages/container/package/charts%2Ftrustee)
at `oci://ghcr.io/schrodit/charts/trustee`.
After the first successful publication, install the pinned chart version with:

```sh
helm upgrade --install trustee oci://ghcr.io/schrodit/charts/trustee --version 0.21.0
```

The [release workflow](.github/workflows/release-trustee-chart.yml) publishes on
GitHub release publication and supports manual runs from the Actions tab. It
builds the pinned `modules/trustee` submodule and uses its `Chart.yaml` version
(currently `0.21.0`) as the registry tag, independently of the GitHub release tag.
Update the submodule to a new chart version before publishing an updated chart.
The workflow uses `GITHUB_TOKEN` with package write permission; no registry
secret is needed. After the first publication, set the package visibility to
public in GitHub's package settings to allow anonymous installation.

### Publish manually

Requires Helm 3.8+ or Helm 4 and a checkout of
[Trustee](https://github.com/confidential-containers/trustee) at `modules/trustee`.
Set `TRUSTEE_DIR=/path/to/trustee` to use another checkout.

```sh
# Build dependencies, lint, and package into dist/.
make trustee-build

# Authenticate to your registry, then build and upload.
helm registry login ghcr.io --username schrodit
make trustee-push OCI_REGISTRY=oci://ghcr.io/schrodit/charts
```

Use a registry namespace you can write to. `OCI_REGISTRY` must omit the chart
name and tag; Helm derives both from `Chart.yaml`. For example, a chart named
`trustee` with version `0.1.0` is published as
`oci://ghcr.io/schrodit/charts/trustee:0.1.0`.
See [Helm's OCI documentation](https://helm.sh/docs/topics/registries/).

`make help` lists targets and configurable paths. Dependency builds use the
chart's lock file when present; Helm resolves dependencies if no lock file exists.
