locals {
  cluster_name = "moisty-boi"
  cluster_endpoint = "kube.hand.technology"
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
      directories = {
        generated = "${local.k8s_apps_root_dir}/metal_lb"
      }
      additional_manifests = [
        <<-EOT
          apiVersion: v1
          kind: ConfigMap
          metadata:
            namespace: metallb-system
            name: config
          data:
            config: |
              address-pools:
              - name: default
                protocol: layer2
                addresses:
                - 10.100.3.0/24
        EOT
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
    ingress_nginx = {
      directories = {
        generated = "${local.helm_apps_root_dir}/ingress_nginx"
      }
      namespace = "ingress-nginx"
      chart = "ingress-nginx/ingress-nginx"
      values = [ yamlencode({
        controller = {
          watchIngressWithoutClass = true
          service = { externalIPs = [ "10.100.3.0" ] }
        }
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
  chart = each.value.chart
  values = each.value.values
}
