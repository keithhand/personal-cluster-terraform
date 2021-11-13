terraform {
  required_providers {
    proxmox = {
      source = "local.test/danitso/proxmox"
      version = "0.4.5"
    }

    unifi = {
      source = "paultyng/unifi"
      version = "0.34.0"
    }
  }
}

locals {
  identifier = var.is_master ? "master" : "worker"
  label = var.is_master ? "${local.identifier}-node" : "${local.identifier}-node"
  sub_id = var.is_master ? 1 : 2
}

resource "proxmox_virtual_environment_vm" "node" {
  count = var.node_count
  name = "${local.label}-${format("%02s", count.index+1)}"
  node_name = "pve"
  vm_id     = "${tonumber("${local.sub_id}00") + count.index+1}"

  disk {
    datastore_id = "local-lvm"
    file_format = "qcow2"
    interface    = "scsi0"
    size = var.storage_gb
  }

  cpu {
    cores = var.cpu.cores
    sockets = var.cpu.sockets
    type = "kvm64"
  }

  cdrom {
    enabled = true
    file_id = "local:iso/talos-amd64.iso"
  }

  memory {
    dedicated = var.mem_gb * 1024
  }

  network_device {
    bridge = "vmbr2"
  }

  operating_system {
    type = "l26"
  }
}

data "unifi_network" "k8s_network" {
  name = "Server - Kubernetes"
}

resource "unifi_user" "node" {
  count = length(proxmox_virtual_environment_vm.node)
  mac = proxmox_virtual_environment_vm.node[count.index].mac_addresses[0]
  name = proxmox_virtual_environment_vm.node[count.index].name
  fixed_ip = "10.100.${local.sub_id}.${count.index+1}"
  network_id = data.unifi_network.k8s_network.id
  lifecycle { ignore_changes = [ ip ] }
}
