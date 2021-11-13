resource "local_file" "talos_node_yaml" {
  count = length(var.nodes)
  filename = "./${var.directories.generated}/${replace(var.nodes[count.index].name, "-node-", "/")}-${substr(base64encode(var.nodes[count.index].mac), 5, 4)}.yaml"
  content = templatefile(var.nodes[count.index].is_master ? "${var.directories.templates}/controlplane.yaml" : 
                                                            "${var.directories.templates}/worker.yaml", { 
    ip_addrs = var.nodes[count.index].ip
    cluster_name = var.cluster_name
    cluster_endpoint = var.cluster_endpoint
    hostname = var.nodes[count.index].name
  })
}

resource "null_resource" "entrypoint_talos_node_yaml" {
  count = length(local_file.talos_node_yaml)
  triggers = { filename = local_file.talos_node_yaml[count.index].filename }
  provisioner "local-exec" {
    command = local_file.talos_node_yaml[count.index].filename
    interpreter = [ "./talos/entrypoint.sh" ]
    environment = {
      NODE_COUNT = count.index
      BOOTSTRAP = var.nodes[count.index].is_bootstrap
      IP = var.nodes[count.index].ip
    }
  }
}
