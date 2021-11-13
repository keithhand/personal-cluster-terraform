output "namespace" {
  value = kubernetes_namespace.primary_namespace.id
}

output "output_secrets" {
  sensitive = true
  value = [
    for i, s in var.get_output_secrets : {
      "name" = s.name
      "secret" = data.kubernetes_secret.output_secrets[i].data[s.path]
      "pretty" = "${s.name} - ${data.kubernetes_secret.output_secrets[i].data[s.path]}"
    }
  ]
}
