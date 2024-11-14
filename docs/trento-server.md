# Trento Server Helm Chart

## Installation

### Requirements

The _Trento Server_ is intended to run in many ways, depending on users' already existing infrastructure, but it's designed to be cloud-native and OS agnostic.
As such, our default installation method provisions a minimal, single node, [K3S] Kubernetes cluster to run its various components in Linux containers.
The suggested physical resources for running all the _Trento Server_ components are 2GB of RAM and 2 CPU cores.
The _Trento Server_ needs to reach the target infrastructure.

### Quick-start installation

An installation script is provided to quickly get you started by automatically provisioning, installing and updating the latest version of Trento.

The script installs a single node K3s cluster and uses the [trento-server Helm chart](../charts/trento-server)
to bootstrap a complete Trento server component.

You can `curl | bash` if you want to live on the edge.

```
curl -sfL https://raw.githubusercontent.com/trento-project/helm-charts/main/scripts/install-server.sh | bash
```

Or you can fetch the script, and then execute it manually.

```
curl -O https://raw.githubusercontent.com/trento-project/helm-charts/main/scripts/install-server.sh
chmod 700 install-server.sh
sudo ./install-server.sh
```

_Note: if a Trento server is already installed in the host, it will be updated._

Please refer to the [Helm chart](#helm-chart) section for more information about the Helm chart.

### Manual installation

#### Helm chart

The [charts/trento-server](charts/trento-server) directory contains the Helm chart for installing Trento Server in a Kubernetes cluster.

#### Install K3S

If installing as root:

```
# curl -sfL https://get.k3s.io | sh
```

If installing as non-root user:

```
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

Export KUBECONFIG env variable:

```
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

Please refer to the [K3S official documentation](https://rancher.com/docs/k3s/latest/en/installation/) for more information about the installation.

#### Install Helm and chart dependencies

Install Helm:

```
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

Please refer to the [Helm official documentation](https://helm.sh/docs/intro/install/) for more information about the installation.

#### Install Trento Server

Add third-party Helm repositories:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Install chart dependencies:

```
cd charts/trento-server/
helm dependency update
```

Install the Trento Server chart:

```
helm install trento .
```

or perform a rolling update:

```
helm upgrade trento . --set trento-web.trentoWebOrigin="trento.example.com"
```

_Note: be sure to replace trento.example.com with a valid hostname that points to the Trento server._

Now you can connect to the web server via `http://localhost` and point the agents to the cluster IP address.

#### Other Helm chart usage examples

Use a different container image (e.g. the `rolling` one):

```
helm install trento . --set trento-web.image.tag="rolling" --set trento-wanda.image.tag="rolling"
```

Use a different container registry:

```
helm install trento . --set trento-web.image.repository="ghcr.io/myrepo/trento-web" --set trento-wanda.image.repository="ghcr.io/myrepo/trento-wanda"
```

Please refer to the the subcharts `values.yaml` for an advanced usage.
