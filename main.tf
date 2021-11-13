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

