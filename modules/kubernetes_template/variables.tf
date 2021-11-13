variable "directories" {
  type = object({
    generated = string
  })
}

variable "namespace" {
  type = string
}

variable "manifest_url" {
  type = string
}

variable "additional_manifests" {
  type = list(string)
  default = []
}

variable "patches" {
  type = list(object({
    object = string
    content = any
  }))
  default = []
}

variable "get_output_secrets" {
  type = list(object({
    name = string
    path = string
  }))
  default = []
}