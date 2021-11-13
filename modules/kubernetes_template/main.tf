resource "kubernetes_namespace" "primary_namespace" {
  metadata {
    name = var.namespace
  }
}
