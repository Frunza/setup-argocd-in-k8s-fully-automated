# Setup ArgoCD in k8s fully automated

## Scenario

You have a `kubernetes` cluster and you want to configure `Argo CD` in a fully automated way. This means a few things:
-you do not want to run any manual command
-you want to set this up in a repository pipeline and running it more times must not break anything
-update `Argo CD` by just changing a version string and push the change to git

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can verify this by running the following command:
```sh
docker --version
```

Set the following environment variable to get access to the `Argo CD` repositories:
- SSH_PRIVATE_KEY

If you set up access to the `Argo CD` repositories via https, you need to provide the following environment variables:
- GIT_USERNAME
- GIT_PASSWORD

For `Terraform` to have access to your cluster, you need the `kubeconfig` file to access the cluster. You can provide its content via an environment variable:
- CLUSTER_KUBE_CONFIG: for convenience, you can add it directly to your profile. This can look like this, for example:
```sh
export CLUSTER_KUBE_CONFIG="apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:64571
  name: kind-kind-cluster
contexts:
- context:
    cluster: kind-kind-cluster
    user: kind-kind-cluster
  name: kind-kind-cluster
current-context: kind-kind-cluster
kind: Config
preferences: {}
users:
- name: kind-kind-cluster
  user:
    client-certificate-data: LS0tLS1CRUdJJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLtFWS0tLS0tCg=="
```
, for a `kind` cluster.
Note the syntax: it needs double quotation marks at the beginning and the end of the ssh key value.
Note: if you use `GitLab`, the value of the environment variable must contain the content only, without the double quotation marks.

## Implementation

First of all, we must make sure that the `Terraform` providers have access to the cluster. The providers accept a file path to the configuration file. To do this, we can write a script to output the content of the CLUSTER_KUBE_CONFIG environment variable to a file:
```sh
# Create /infrastructure/.kube if it does not exist
mkdir -p /infrastructure/.kube

# Write contents of CLUSTER_KUBE_CONFIG to /infrastructure/.kube/config
echo "$CLUSTER_KUBE_CONFIG" > /infrastructure/.kube/config
```

To set up `Argo CD` with the desired requirements, we can install it in the cluster via a helm chart and specifying all extra parameters. By providing `Argo CD` version as a parameter, `Terraform` will update `Terraform` whenever the version changes. `Argo CD` access to the desired repositories can be done via *https* or *ssh*. Before this, we want to create a namespace for `Argo CD` via `Terraform` so that the namespace also gets deleted if we destroy the infrastructure.

The `Argo CD` namespace definition can be defined as:
```sh
resource "kubernetes_manifest" "argocdNamespace" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name" = "argocd"
    }
  }
}
```

If we want to provide `Argo CD` access to the desired repositories via *https* we can use a file to provide extra configuration, and reference it from `Terraform`:
```sh
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocdVersion
  namespace        = "argocd"

  values = [
    file("/infrastructure/resources/k8s/argo-values.yaml")
  ]
  depends_on = [ kubernetes_manifest.argocdNamespace ]
}
```

The external file with the `Argo CD` value would then lok like:
```sh
configs:
  repositories:
    - url: git@github.com:Frunza/argo-test.git
      username: _GIT_USERNAME_
      password: _GIT_PASSWORD_
    - url: git@github.com:Frunza/argo-test2.git
      username: _GIT_USERNAME_
      password: _GIT_PASSWORD_
```

Now we just have to update the placeholders with the values of environment variables. This can be done in a script:
```sh
sed -i "s/_GIT_USERNAME_/${GIT_USERNAME}/" ./resources/k8s/argo-values.yaml
echo "Replacement of GIT_USERNAME done"
sed -i "s/_GIT_PASSWORD_/${GIT_PASSWORD}/" ./resources/k8s/argo-values.yaml
echo "Replacement of GIT_PASSWORD done"
```

If we want to provide `Argo CD` access to the desired repositories via *ssh* we need to configure the `Argo CD` values from the `Terraform` configuration because the replacement handles extra characters better. This could look like:
```sh
variable "sshPrivateKeyFile" {
  description = "Path to the SSH private key file"
  type        = string
  default     = "/infrastructure/ssh-private-key.pem"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocdVersion
  namespace        = "argocd"

  values = [
    <<-EOF
    configs:
      repositories:
        - url: git@github.com:Frunza/argo-test.git
          enableLfs: "true"
          insecure: "true"
          sshPrivateKey: |
            ${file(var.sshPrivateKeyFile)}
        - url: git@github.com:Frunza/argo-test2.git
          enableLfs: "true"
          insecure: "true"
          sshPrivateKey: |
            ${file(var.sshPrivateKeyFile)}
    EOF
  ]
  depends_on = [ kubernetes_manifest.argocdNamespace ]
}
```
Here we are reading the SSH key from a file and injecting it in the `Argo CD` values. Do note that the SSH key must be inserted inside a *yaml* configuration. This means that indentation must be correctly handled. To do this, we must add that extra indentation when writing the value of the SSH key environment file to a file:
```sh
# Write contents of SSH_PRIVATE_KEY to /infrastructure/ssh-private-key.pem
echo "$SSH_PRIVATE_KEY" > /infrastructure/ssh-private-key.pem

# Add indentation (8 spaces) to each line after the first one; this is required because the private key must have indentation when injected into the argo config file
sed -i '2,$s/^/        /' /infrastructure/ssh-private-key.pem
```

Now we can add an `Argo CD Application` so that it can observe changes from some repositories:
```sh
resource "kubernetes_manifest" "argoTestApp" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "test-app"
      "namespace" = "argocd"
    }
    "spec" = {
      "project" = "default"
      "source" = {
        "repoURL"        = "git@github.com:Frunza/argo-test.git"
        "targetRevision" = "HEAD"
        "path"           = "test-app"
      }
      "destination" = {
        "server"   = "https://kubernetes.default.svc"
      }
      "syncPolicy" = {
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
      }
    }
  }
}
```
If you want to access the repository via *https* make sure to change the *repoURL* to *https://github.com/Frunza/argo-test.git*.

*https://github.com/Frunza/argo-test.git* does not exist, but the contents of it could look like:
```sh
.
├── README.md
└── test-app
    ├── deployment.yaml
    └── namespace.yaml
```

*deployment.yaml* could look like:
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: nginx:latest
        ports:
        - containerPort: 80
```
and *namespace.yaml* could look like:
```sh
apiVersion: v1
kind: Namespace
metadata:
  name: test-app
```
Adding the namespace here is a good idea, because we want to have the namespace automatically deleted if it disappears from the repository.

## Usage

Since everything runs inside a docker container, all you have to do is call the `update.sh` script.

You can also use a local cluster for testing purposes. For example, you can create a cluster with `kind`:
```sh
kind create cluster --name my-kind-cluster
```
The context for the new cluster will automatically be added to your `kubeconfig` file.

Direct `Argo CD` UI access is disabled. To access it, follow the steps below:

Establish a port-forward from `Argo CD` server to localhost:
```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Retrieve the autogenerated password by running:
```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Navigate to **localhost:8080** in your browser. Login as **admin** user and the retrieved password.
