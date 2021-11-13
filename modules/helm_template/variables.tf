variable "directories" {
  type = object({
    generated = string
  })
}

variable "namespace" {
  type = string
}

variable "chart" {
  type = string
}

variable "values" {
  default = []
}
