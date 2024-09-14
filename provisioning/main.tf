# Configure the Hetzner Cloud Provider
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.5"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    bucket = "auberon-tfstate"
    key    = "terraform.tfstate"
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "sops" {}

data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

data "cloudinit_config" "k8s_node" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml", {
      username = data.sops_file.secrets.data["username"]
      user_hashed_password = data.sops_file.secrets.data["user_hashed_password"]
      user_ssh_public_key = data.sops_file.secrets.data["user_ssh_public_key"]
      github_username = data.sops_file.secrets.data["github_username"]
      github_repo = data.sops_file.secrets.data["github_repo"]
      github_token = data.sops_file.secrets.data["github_token"]
    })
  }
}

resource "hcloud_server" "cluster" {
  name        = "auberon2"
  image       = "ubuntu-24.04"
  server_type = "cx22"
  location    = "nbg1"
  backups     = true
  user_data   = data.cloudinit_config.k8s_node.rendered
}

resource "hcloud_firewall" "cluster-firewall" {
  name = "cluster-firewall2"
  apply_to {
    server = hcloud_server.cluster.id
  }
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

output "server_ip" {
  value = hcloud_server.cluster.ipv4_address
}