locals {
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
