# WARNING!
# This script requires .k3sconf file under your home directory, must contain:
# GH_REPO_OWNER=<infrastructure repository owner> (won't work on organization as this script uses --personal option during flux initialization)
# GH_REPO_NAME=<infrastructure repository name>
# GH_REPO_BRANCH=<repository main branch>
# GH_REPO_CLUSTER_PATH=<path to cluster specs in your repository>
# GITHUB_TOKEN=<github access token> (token must provide proper access rights to make your repo accessable within the cluster)

if ! [ -f .k3sconf ]; then
    echo 'Error: k3s setup configuration file does not exist (~/.k3sconf)'
    exit 1
fi

export $(cat ~/.k3sconf)

# Installs flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Installs istio ctl
curl -L https://istio.io/downloadIstio | sh -
sudo cp -R istio-1.17.0/bin/istioctl /usr/local/bin/istioctl

# Sets up k3s without traefik and local-storage as it is going to be provided by istio
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="777" INSTALL_K3S_EXEC="--disable traefik --disable local-storage" sh -

# Sets up proxy on port 8080
kubectl proxy --port 8080 &

# Wait until proxy initializes
sleep 1

# Sets up flux-system on a cluster
flux bootstrap github \
  --owner=$GH_REPO_OWNER \
  --repository=$GH_REPO_NAME \
  --branch=$GH_REPO_BRANCH \
  --path=$GH_REPO_CLUSTER_PATH \
  --personal

# Sets up istio-system on a cluster
istioctl install -y

echo 'Setup finished!'
