# WARNING!
# This script requires .k3sconf file under your home directory, must contain:
# GH_REPO_OWNER=<infrastructure repository owner> (won't work on organization as this script uses --personal option during flux initialization)
# GH_REPO_NAME=<infrastructure repository name>
# GH_REPO_BRANCH=<repository main branch>
# GH_REPO_CLUSTER_PATH=<path to cluster specs in your repository>
# GITHUB_TOKEN=<github access token> (token must provide proper access rights to make your repo accessable within the cluster)
# REGRU_USER=<regru login, most likely email>
# REGRU_PASSWORD=<regru password>
# ACME_EMAIL=<email used for ACME challenge>

if ! [ -f .k3sconf ]; then
    echo 'Error: k3s setup configuration file does not exist (~/.k3sconf)'
    exit 1
fi

export $(cat ~/.k3sconf)

# Installs flux CLI
echo -e "---------------\nInstalling Flux\n---------------\n"
curl -s https://fluxcd.io/install.sh | sudo bash

# Installs istio ctl
echo -e "-------------------\nInstalling Istioctl\n-------------------\n"
curl -L https://istio.io/downloadIstio | sh -
sudo cp -R istio-1.17.0/bin/istioctl /usr/local/bin/istioctl

# Installs helm
echo -e "---------------\nInstalling Helm\n---------------\n"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Sets up k3s without traefik and local-storage as it is going to be provided by istio
echo -e "-------------------------\nInstalling & Starting k3s\n-------------------------\n"
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="777" INSTALL_K3S_EXEC="--disable traefik --disable local-storage" sh -

# Sets up proxy on port 8080
echo -e "----------------------\nStarting kubectl proxy\n----------------------\n"
kubectl proxy --port 8080 &

# Wait until proxy initializes
echo "Waiting for 1 sec..."
sleep 1

# Sets up istio-system on a cluster
echo -e "------------------------------------\nInstalling istio system on a cluster\n------------------------------------\n"
istioctl install -y

# Installs cert-manager
echo -e "------------------------------------\nInstalling cert manager on a cluster\n------------------------------------\n"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Wait for cert-manager to initialize
echo "Waiting for 60 sec for cert-manager to initialize..."
sleep 60

# Sets up ClusterIssuer for regru (optional)
# Cloning repo with all needed for configuration stuff
echo -e "-----------------------------\nSetting up regru cert manager\n-----------------------------\n"
git clone https://github.com/flant/cert-manager-webhook-regru.git
cd cert-manager-webhook-regru
# Updating values.yaml file before helm install
echo "issuer:
  image: ghcr.io/flant/cluster-issuer-regru:latest
  user: $REGRU_USER
  password: $REGRU_PASSWORD

groupName:
  name: acme.regru.ru

certManager:
  namespace: cert-manager
  serviceAccountName: cert-manager

nameOverride: ""
fullnameOverride: ""

service:
  type: ClusterIP
  port: 443

webhook:
  hostNetwork: true

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    memory: 256Mi


nodeSelector: {}

tolerations: []

affinity: {}" > ./helm/values.yaml
# Override secrets-reader ClusterRule for cluster-issuer SA (probably a regru-webhook bug, may be fixed in next releases)
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
---
# Grant permissions to read secrets inside the cluster to allow to have issuer in another namespace than the webhook
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:secrets-reader
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
rules:
  - apiGroups:
      - ''
      - 'flowcontrol.apiserver.k8s.io'
    resources:
      - '*'
    verbs:
      - 'get'
      - 'list'
      - 'watch'
---
# Bind the previously created role to the webhook service account to allow reading from secrets in all namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:secrets-reader
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:secrets-reader
subjects:
  - apiGroup: \"\"
    kind: ServiceAccount
    name: {{ include \"cert-manager-webhook-regru.fullname\" . }}
    namespace: {{ .Release.Namespace }}
---
# Grant the webhook permission to read the ConfigMap containing the Kubernetes
# apiserver's requestheader-ca-certificate.
# This ConfigMap is automatically created by the Kubernetes apiserver.
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:webhook-authentication-reader
  namespace: kube-system
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
  - apiGroup: \"\"
    kind: ServiceAccount
    name: {{ include \"cert-manager-webhook-regru.fullname\" . }}
    namespace: {{ .Release.Namespace }}
---
# apiserver gets the auth-delegator role to delegate auth decisions to
# the core apiserver
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:auth-delegator
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - apiGroup: \"\"
    kind: ServiceAccount
    name: {{ include \"cert-manager-webhook-regru.fullname\" . }}
    namespace: {{ .Release.Namespace }}
---
# Grant cert-manager permission to validate using our apiserver
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:domain-solver
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
rules:
  - apiGroups:
      - {{ .Values.groupName.name }}
    resources:
      - '*'
    verbs:
      - 'create'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:domain-solver
  labels:
    app: {{ include \"cert-manager-webhook-regru.name\" . }}
    chart: {{ include \"cert-manager-webhook-regru.chart\" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include \"cert-manager-webhook-regru.fullname\" . }}:domain-solver
subjects:
  - apiGroup: \"\"
    kind: ServiceAccount
    name: {{ .Values.certManager.serviceAccountName }}
    namespace: {{ .Values.certManager.namespace }}" > ./helm/templates/rbac.yaml
# Creating ClusterIssuer resource and applying it
echo "apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: regru-dns
spec:
  acme:
    email: $ACME_EMAIL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cert-manager-letsencrypt-private-key
    solvers:
      - dns01:
          webhook:
            config:
              regruPasswordSecretRef:
                name: regru-password
                key: REGRU_PASSWORD
            groupName: acme.regru.ru
            solverName: regru-dns" > ./cluster.issuer.yaml
kubectl create -f cluster.issuer.yaml
# Installing via helm
helm install -n cert-manager regru-webhook ./helm
cd ..
rm -rf cert-manager-webhook-regru

# Sets up flux-system on a cluster
flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=$GH_REPO_OWNER \
  --repository=$GH_REPO_NAME \
  --branch=$GH_REPO_BRANCH \
  --path=$GH_REPO_CLUSTER_PATH \
  --read-write-key \
  --personal

echo -e '---------------\nSetup finished!\n---------------\n'
