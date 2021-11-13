variable "directories" {
  type = object({
    templates = string
    generated = string
  })
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

# values exported in modules.node_template.outputs.locals
variable "nodes" {
  type = list(object({
    vm_id = string
    name = string
    mac = string
    ip = string
    is_master = bool
    is_bootstrap = bool
  }))
}
