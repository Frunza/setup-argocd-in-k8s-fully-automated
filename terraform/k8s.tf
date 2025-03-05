# ArgoCd

resource "kubernetes_manifest" "argocdNamespace" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name" = "argocd"
    }
  }
}

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
#   values = [
#     file("/infrastructure/resources/k8s/argo-values.yaml")
#   ]
  depends_on = [ kubernetes_manifest.argocdNamespace ]
}

# ArgoCd Application

resource "kubernetes_manifest" "appNamespace" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name" = "test-app"
    }
  }
}

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
       #"repoURL"        = "https://github.com/Frunza/argo-test.git"
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
  depends_on = [ kubernetes_manifest.appNamespace ]
}
