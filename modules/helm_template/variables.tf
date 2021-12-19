variable "directories" {
  type = object({
    generated = string
  })
}

variable "namespace" {
  type = string
}

variable "chart_name" {
  type = string
}

variable "chart_version" {
  type = string
  default = ""
}

variable "values" {
  default = []
}

variable "additional_manifests" {
  type = list
  default = []
}
