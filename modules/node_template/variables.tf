variable "cluster_endpoint" {
  description = "Access url used for the cluster."
}

variable "is_master" {
  description = "Required value to determine whether to set up as master node."
}

variable "node_count" {
  description = "Determines the number of nodes to create."
  default = 1
}

variable "mem_gb" {
  description = "Sets the amount of memory per node (GB)."
  default = "2"
}

variable "storage_gb" {
  description = "Sets the amount of storage per node (GB)."
  default = "32"
}

variable "cpu" {
  description = "Sets the cpu properties per node."
  default = {
    sockets = 1
    cores = 2
  }
}