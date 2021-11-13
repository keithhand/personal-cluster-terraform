locals {
  nodes = flatten([
    for node_key, node in proxmox_virtual_environment_vm.node.*: {
      vm_id = node.vm_id
      name = node.name
      mac = node.mac_addresses[0]
    }
  ])
  networks = flatten([
    for network_key, network in unifi_user.node.*: {
      ip = network.fixed_ip
    }
  ])
  nodes_combined = flatten([
    for k, v in local.nodes: {
      vm_id = local.nodes[k].vm_id
      name = local.nodes[k].name
      mac = local.nodes[k].mac
      ip = local.networks[k].ip
      is_master = var.is_master
      is_bootstrap = var.is_master && k == 0
    }
  ])
}

output "nodes" {
  value = {
    pretty = "Created ${length(local.nodes)} ${local.identifier} nodes between ${local.networks[0].ip} and ${local.networks[length(local.nodes)-1].ip}"
    details = local.nodes_combined
  }
}
