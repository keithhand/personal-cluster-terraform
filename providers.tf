terraform {
  required_providers {
    proxmox = {
      source = "local.test/danitso/proxmox"
    }

    unifi = {
      source = "paultyng/unifi"
    }
  }
}

locals {
  allow_insecure = true
}

provider "proxmox" {
  virtual_environment {
    insecure = local.allow_insecure
  }
}

provider "unifi" {
  allow_insecure = local.allow_insecure
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
