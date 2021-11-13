resource "kubernetes_namespace" "chart_namespace" {
  metadata {
    name = var.namespace
  }
}
