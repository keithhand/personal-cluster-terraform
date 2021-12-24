locals {
  cluster_name = "moisty-boi"
  cluster_endpoint = "10.0.0.1"
  master = {
    count = 3
    mem_gb = 4
    storage_gb = 32
    cpu = {
      cores = 2
      sockets = 1
    }
  }
  worker = {
    count = 5
    mem_gb = 10
    storage_gb = 32
    cpu = {
      cores = 4
      sockets = 1
    }
  }
}

module "master_nodes" {
  source = "./modules/node_template"
  cluster_endpoint = local.cluster_endpoint
  is_master = true
  mem_gb = local.master.mem_gb
  node_count = local.master.count
  storage_gb = local.master.storage_gb
  cpu = {
    cores = local.master.cpu.cores
    sockets = local.master.cpu.sockets
  }
}

module "worker_nodes" {
  source = "./modules/node_template"
  cluster_endpoint = local.cluster_endpoint
  is_master = false
  mem_gb = local.worker.mem_gb
  node_count = local.worker.count
  storage_gb = local.worker.storage_gb
  cpu = {
    cores = local.worker.cpu.cores
    sockets = local.worker.cpu.sockets
  }
}

locals {
  talos_root_dir = "./talos"
  talos = {
    directories = {
      templates = "${local.talos_root_dir}/templates"
      generated = "${local.talos_root_dir}/generated"
    }
  }
}

module "talos_os" {
  source = "./modules/talos_os"
  directories = local.talos.directories
  cluster_name = local.cluster_name
  cluster_endpoint = local.cluster_endpoint
  nodes = flatten([ 
    module.master_nodes.nodes.details, 
    module.worker_nodes.nodes.details
  ])
}

locals {
  k8s_apps_root_dir = "./k8s_apps"
  k8s_apps = {
    metal_lb = {
      namespace = "metallb-system"
      manifest_url = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
      directories = { generated = "${local.k8s_apps_root_dir}/metal_lb" }
      additional_manifests = [
        {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata = {
            namespace = "metallb-system"
            name = "config"
          }
          data = {
            config = <<-EOT
              address-pools:
              - name: default
                protocol: layer2
                addresses:
                - 10.100.3.0/24
            EOT
          }
        }
      ]
    }
  }
}

module "k8s_apps" {
  depends_on = [ module.talos_os ]
  for_each = local.k8s_apps
  source = "./modules/kubernetes_template"
  directories = each.value.directories
  namespace = each.value.namespace
  manifest_url = each.value.manifest_url
  additional_manifests = lookup(each.value, "additional_manifests", [])
  patches = lookup(each.value, "patches", [])
  get_output_secrets = lookup(each.value, "get_output_secrets", [])
}

locals {
  helm_apps_root_dir = "./helm_apps"
  helm_apps = {
    traefik = {
      directories = {
        generated = "${local.helm_apps_root_dir}/traefik"
      }
      namespace = "traefik"
      chart = {
        name = "traefik/traefik"
        version = "10.9.0"
      }
      values = [ yamlencode({
        persistence = { enabled = true }
        providers = {
          kubernetesIngress = {
            publishedService = { enabled = true }}
        }
        ingressClass = {
          enabled = true
          isDefaultClass = true
        }
        ports = {
          web = { redirectTo = "websecure" }
          websecure = {
            tls = {
              enabled = true
              certResolver = "cloudflare"
              domains = [
                {
                  main = "hand.technology"
                  sans = [ "*.hand.technology" ]
                },
                {
                  main = "khand.dev"
                  sans = [ "*.khand.dev" ]
                },
              ]
            }
          }
        }
        additionalArguments = [
          "--certificatesResolvers.cloudflare.acme.dnschallenge=true",
          "--certificatesResolvers.cloudflare.acme.dnsChallenge.provider=cloudflare",
          "--certificatesResolvers.cloudflare.acme.email=keith@khand.dev",
          "--certificatesResolvers.cloudflare.acme.storage=/data/cf.json",
        ]
        env = [
          {
            name = "CF_DNS_API_TOKEN"
            valueFrom = {
              secretKeyRef = {
                name = "cloudflare-api"
                key = "token"
              }
            }
          },
        ]
      })]
    }
    nfs_provisioner = {
      directories = {
        generated = "${local.helm_apps_root_dir}/nfs_provisioner"
      }
      namespace = "nfs-provisioner"
      chart = {
        name = "nfs-subdir-external-provisioner/nfs-subdir-external-provisioner"
        version = "4.0.14"
      }
      values = [ yamlencode({
        image = {
          tag = "v4.0.2"
        }

        nfs = {
          server = "10.10.1.1"
          path = "/mnt/storage/k8s/export"
          mountOptions = [ "nolock" ]
        }

        storageClass = {
          name = "nfs"
          defaultClass = true
          pathPattern = "$${.PVC.namespace}/$${.PVC.name}"
          onDelete = "delete"
        }
      })]
    }
    argo_cd = {
      directories = { generated = "${local.helm_apps_root_dir}/argo_cd" }
      namespace = "argocd"
      chart = {
        name = "argo/argo-cd"
        version = "3.29.0"
      }
      values = [ yamlencode({
        server = {
          extraArgs = [ "--insecure" ]
          ingress = {
            enabled = true
            annotations = { "traefik.ingress.kubernetes.io/router.middlewares": "traefik-forward-auth-traefik-forward-auth@kubernetescrd" }
            hosts = [ "argo.khand.dev" ]
          }
        }
      })]
    }
    vault = {
      directories = { generated = "${local.helm_apps_root_dir}/vault" }
      namespace = "vault"
      chart = {
        name = "hashicorp/vault"
        version = "0.18.0"
      }
      values = [ yamlencode({
        server = {
          ingress = {
            enabled = true
            ingressClassName = "traefik"
            annotations = { "traefik.ingress.kubernetes.io/router.middlewares": "traefik-forward-auth-traefik-forward-auth@kubernetescrd" }
            hosts = [{ host = "vault.khand.dev" }]
          }
        }
      })]
    }
    external_secrets = {
      directories = { generated = "${local.helm_apps_root_dir}/external_secrets" }
      namespace = "external-secrets"
      chart = {
        name = "external-secrets/external-secrets"
        version = "0.3.10"
      }
      values = [ yamlencode({ installCRDs = true })]
    }
    artifactory = {
      directories = { generated = "${local.helm_apps_root_dir}/artifactory" }
      namespace = "artifactory"
      chart = {
        name = "jfrog/artifactory-oss"
        version = "107.29.8"
      }
      values = [ yamlencode({
        artifactory = {
          nginx = { service = { type = "ClusterIP" }}
          ingress = {
            enabled = true
            annotations = { "traefik.ingress.kubernetes.io/router.middlewares": "traefik-forward-auth-traefik-forward-auth@kubernetescrd" }
            hosts = [ "art.khand.dev" ]
          }
          postgresql = { existingSecret = "artifactory-postgresql" }
        }
      })]
    }
    grafana_loki_stack = {
      directories = { generated = "${local.helm_apps_root_dir}/grafana" }
      namespace = "grafana"
      chart = {
        name = "grafana/loki-stack"
        version = "2.5.0"
      }
      values = [ yamlencode({
        grafana = {
          enabled = true
          persistence = { enabled = true }
          ingress = {
            enabled = true
            annotations = { "traefik.ingress.kubernetes.io/router.middlewares": "traefik-forward-auth-traefik-forward-auth@kubernetescrd" }
            hosts = [ "logs.khand.dev" ]
          }
          initChownData = { enabled = false }
        }
        prometheus = { enabled = true }
        loki = { persistence = { enabled = true }}
      })] 
    }
  }
}

module "helm_apps" {
  depends_on = [ module.k8s_apps ]
  for_each = local.helm_apps
  source = "./modules/helm_template"
  directories = each.value.directories
  namespace = each.value.namespace
  chart_name = each.value.chart.name
  chart_version = lookup(each.value.chart, "version", "")
  values = lookup(each.value, "values", [])
  additional_manifests = lookup(each.value, "additional_manifests", [])
}

locals {
  custom_resource_manifests = [
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind = "AppProject"
      metadata = {
        name = "game-servers"
        namespace = "argocd"
      }
      spec = {
        sourceRepos = [ "*" ]
        destinations = [
          {
            server = "https://kubernetes.default.svc"
            namespace = "games-*"
          }
        ]
      }
    },
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind = "Application"
      metadata = {
        name = "application-repo"
        namespace = "argocd"
      }
      spec = {
        destination = {
          namespace = "argocd"
          server = "https://kubernetes.default.svc"
        }
        source = {
          path = "argocd_apps"
          repoURL = "https://github.com/keithhand/personal-cluster-terraform.git"
          targetRevision = "HEAD"
        }
        project = "default"
        syncPolicy = {
          automated = {
            prune = "true"
            selfHeal = "true"
          }
        }
      }
    },
    {
      apiVersion = "external-secrets.io/v1alpha1"
      kind = "ClusterSecretStore"
      metadata = { name = "vault-backend" }
      spec = {
        provider = {
          vault = {
            server = "http://vault.vault.svc.cluster.local:8200"
            path = "kv"
            version = "v2"
            auth = {
              tokenSecretRef = {
                name = "vault-token"
                namespace = "external-secrets"
                key = "token"
              }
            }
          }
        }
      }
    },
    {
      apiVersion = "external-secrets.io/v1alpha1"
      kind = "ExternalSecret"
      metadata = {
        name = "cloudflare-api"
        namespace = "traefik"
      }
      spec = {
        refreshInterval = "15s"
        target = {}
        secretStoreRef = {
          name = "vault-backend"
          kind = "ClusterSecretStore"
        }
        data = [
          {
            secretKey = "token"
            remoteRef = {
              key = "cloudflare"
              property = "api-token"
            }
          },
        ]
      }
    },
    {
      apiVersion = "external-secrets.io/v1alpha1"
      kind = "ExternalSecret"
      metadata = {
        name = "artifactory-postgresql"
        namespace = "artifactory"
      }
      spec = {
        refreshInterval = "15s"
        target = {}
        secretStoreRef = {
          name = "vault-backend"
          kind = "ClusterSecretStore"
        }
        data = [
          {
            secretKey = "postgresql-password"
            remoteRef = {
              key = "artifactory"
              property = "postgresql-password"
            }
          },
          {
            secretKey = "postgresql-postgres-password"
            remoteRef = {
              key = "artifactory"
              property = "postgresql-postgres-password"
            }
          },
        ]
      }
    },
  ]
}

resource "kubernetes_manifest" "custom_resource_manifests" {
  depends_on = [ module.k8s_apps, module.helm_apps ]
  count = length(local.custom_resource_manifests)
  manifest = local.custom_resource_manifests[count.index]
}
