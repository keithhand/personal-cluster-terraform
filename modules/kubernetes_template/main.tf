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
