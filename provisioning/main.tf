# Configure the Hetzner Cloud Provider
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.4.0"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    bucket                      = "auberon-tfstate"
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "sops" {}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

data "cloudinit_config" "k8s_node" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml", {
      username             = data.sops_file.secrets.data["username"]
      user_hashed_password = data.sops_file.secrets.data["user_hashed_password"]
      user_ssh_public_keys = [
        for key in split("\n", data.sops_file.secrets.data["user_ssh_public_keys"]) :
        key if trimspace(key) != ""
      ]
    })
  }
}

resource "hcloud_server" "cluster" {
  name        = "auberon"
  image       = "ubuntu-24.04"
  server_type = "cx22"
  location    = "nbg1"
  backups     = true
  user_data   = data.cloudinit_config.k8s_node.rendered
}

resource "hcloud_firewall" "cluster-firewall" {
  name = "cluster-firewall"
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

data "cloudflare_zones" "domain" {
  name = data.sops_file.secrets.data["domain_name"]
}

resource "cloudflare_dns_record" "cluster" {
  zone_id = data.cloudflare_zones.domain.result[0].id
  name    = "@"
  content = hcloud_server.cluster.ipv4_address
  type    = "A"
  proxied = false
  ttl = 3600
}

resource "cloudflare_dns_record" "cluster_wildcard" {
  zone_id = data.cloudflare_zones.domain.result[0].id
  name    = "*"
  content = hcloud_server.cluster.ipv4_address
  type    = "A"
  proxied = false
  ttl = 3600
}

resource "cloudflare_dns_record" "caa" {
  zone_id = data.cloudflare_zones.domain.result[0].id
  name    = "@"
  type    = "CAA"
  data = {
    flags = "0"
    tag   = "issue"
    value = "letsencrypt.org"
  }
  ttl = 3600
}

resource "cloudflare_dns_record" "cluster_ipv6_wildcard" {
  zone_id = data.cloudflare_zones.domain.result[0].id
  name    = "@"
  content = hcloud_server.cluster.ipv6_address
  type    = "AAAA"
  proxied = false
  ttl = 3600
}

resource "cloudflare_dns_record" "cluster_ipv6" {
  zone_id = data.cloudflare_zones.domain.result[0].id
  name    = "*"
  content = hcloud_server.cluster.ipv6_address
  type    = "AAAA"
  proxied = false
  ttl = 3600
}

output "server_ip" {
  value = hcloud_server.cluster.ipv4_address
}

output "cloud_init_raw" {
  value = templatefile("${path.module}/cloud-init.yaml", {
    username             = data.sops_file.secrets.data["username"]
    user_hashed_password = data.sops_file.secrets.data["user_hashed_password"]
    user_ssh_public_keys = [
      for key in split("\n", data.sops_file.secrets.data["user_ssh_public_keys"]) :
      key if trimspace(key) != ""
    ]
  })
  sensitive = true
}
