resource "kubernetes_namespace" "primary_namespace" {
  metadata {
    name = var.namespace
  }
}

data "http" "primary_manifest" {
  url = var.manifest_url
  request_headers = {
    Accept = "text/plain"
  }
}

resource "local_file" "primary_manifest" {
  filename = "${var.directories.generated}/manifests.d/manifest.0.yaml"
  content = data.http.primary_manifest.body
}

resource "local_file" "additional_manifests" {
  count = length(var.additional_manifests)
  filename = "${var.directories.generated}/manifests.d/manifest.${count.index + 1}.yaml"
  content = var.additional_manifests[count.index]
}

resource "local_file" "manifest_yaml" {
  depends_on = [ kubernetes_namespace.primary_namespace ]
  filename = "${var.directories.generated}/manifest.yaml"
  content = join("---\n", concat([local_file.primary_manifest.content], local_file.additional_manifests.*.content))

  provisioner "local-exec" {
    command = "kubectl apply -n ${kubernetes_namespace.primary_namespace.id} -f ${self.filename}"
  }
}

resource "local_file" "patch_jsons" {
  count = length(var.patches)
  filename = "${var.directories.generated}/patches/patch.${count.index}.json"
  content = jsonencode(var.patches[count.index].content)
}

resource "null_resource" "apply_patches" {
  depends_on = [ local_file.manifest_yaml ]
  count = length(var.patches)
  triggers = { manifest_yaml = local_file.manifest_yaml.id }
  
  provisioner "local-exec" {
    command = "kubectl patch ${var.patches[count.index].object} -n ${kubernetes_namespace.primary_namespace.id} --patch-file ${local_file.patch_jsons[count.index].filename}"
  }
}

data "kubernetes_secret" "output_secrets" {
  count = length(var.get_output_secrets)
  metadata {
    name = var.get_output_secrets[count.index].name
    namespace = kubernetes_namespace.primary_namespace.id
  }
}
