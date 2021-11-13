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

resource "local_file" "config_talosconfig" {
  filename = "${var.directories.generated}/talosconfig"
  content = templatefile("${var.directories.templates}/talosconfig.yaml", { 
    cluster_name = var.cluster_name
    cluster_endpoint = var.cluster_endpoint 
  })

  provisioner "local-exec" {
    command = "cp $HOME/.talos/config $HOME/.talos/config.b | true && cp ${self.filename} $HOME/.talos/config"
  }
}

resource "null_resource" "config_node_ips" {
  triggers = { talosconfig = local_file.config_talosconfig.id }

  provisioner "local-exec" {
    command = "talosctl config node ${join(" ", var.nodes.*.ip)}"
  }
}
