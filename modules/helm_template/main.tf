locals {
  name = var.namespace
  chart = split("/", var.chart_name)
  chart_repo = local.chart[0]
  chart_name = join("/", slice(local.chart, 1, length(local.chart)))
  generated_dir = "${var.directories.generated}/${var.namespace}"
}

resource "kubernetes_namespace" "chart_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "local_file" "values_yaml_d" {
  count = length(var.values)
  filename = "${local.generated_dir}/values.yaml.d/values.${count.index}.yaml"
  content = var.values[count.index]
}

resource "local_file" "values_yaml" {
  filename = "${local.generated_dir}/values.yaml"
  content = join("---\n", local_file.values_yaml_d.*.content)
}

resource "helm_release" "chart" {
  name = local.name
  namespace = kubernetes_namespace.chart_namespace.id
  repository = local.chart_repo
  chart = local.chart_name
  values = var.values
  version = var.chart_version
}

resource "local_file" "additional_manifests" {
  count = length(var.additional_manifests)
  filename = "${var.directories.generated}/manifests.d/manifest.${count.index + 1}.yaml"
  content = yamlencode(var.additional_manifests[count.index])
}

resource "kubernetes_manifest" "additional_manifests" {
  count = length(var.additional_manifests)
  manifest = var.additional_manifests[count.index]
}
