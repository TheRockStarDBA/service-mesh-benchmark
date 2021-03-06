# Required variables
variable "dns_zone" {
  type        = "string"
  description = "DNS zone for cluster e.g. cluster.example.com"
}
variable "packet_project_id" {
  type        = "string"
  description = "Packet project ID"
}
variable "management_cidrs" {
  type        = "list"
  description = "List of CIDRs allowed to connect to cluster."
}
variable "packet_auth_token" {
  type        = "string"
  description = "Packet auth token."
}

# Optional variables
variable "cluster_name" {
  type        = "string"
  description = "Name of the cluster."
  default     = "cluster"
}
variable "facility" {
  type        = "string"
  description = "Packet facility name."
  default     = "ams1"
}
variable "ssh_keys" {
  type        = "list"
  description = "List of SSH public key files or SSH public keys."
  default     = [
    "~/.ssh/.id_rsa.pub"
  ]
}

data "aws_route53_zone" "cluster" {
  name = "${var.dns_zone}."

  provider = "aws.default"
}

data "packet_precreated_ip_block" "ipv4" {
  facility         = "${var.facility}"
  project_id       = "${var.packet_project_id}"
  address_family   = 4
  public           = false

  provider = "packet.default"
}

module "packet-svc-mesh-benchmark" {
  # TODO pin to specific ref eg. "?ref=v1.14.1"
  # TODO change to lokomotive-kubernetes
  # source = "git::https://github.com/kinvolk/lokomotive-kubernetes//packet/flatcar-linux/kubernetes?ref=v1.14.1"
  source = "git::ssh://git@github.com/kinvolk/lokomotive-kubernetes-private.git//packet/flatcar-linux/kubernetes"

  providers = {
    aws      = "aws.default"
    local    = "local.default"
    null     = "null.default"
    template = "template.default"
    tls      = "tls.default"
    packet   = "packet.default"
  }

  dns_zone    = "${var.dns_zone}"
  dns_zone_id = "${data.aws_route53_zone.cluster.zone_id}"

  ssh_keys  = ["$${var.ssh_keys}"]
  asset_dir = "../assets"

  cluster_name = "${var.cluster_name}"
  project_id   = "${var.packet_project_id}"
  facility     = "${var.facility}"

  controller_count = "1"

  # This should be 2 or higher, as one worker node needs to be dedicated for running load generator
  worker_count              = "2"
  worker_nodes_hostnames    = "${concat("${module.worker-pool-0.worker_nodes_hostname}")}"
  worker_nodes_public_ipv4s = "${concat("${module.worker-pool-0.worker_nodes_public_ipv4}")}"
  management_cidrs = ["${var.management_cidrs}"]
  node_private_cidr = "${data.packet_precreated_ip_block.ipv4.cidr_notation}"

  enable_aggregation = "true"
}


module "worker-pool-0" {
  # TODO pin to specific ref eg. "?ref=v1.14.1"
  # TODO change to lokomotive-kubernetes
  # source = "git::https://github.com/kinvolk/lokomotive-kubernetes//packet/flatcar-linux/kubernetes/workers?ref=v1.14.1"
  source = "git::ssh://git@github.com/kinvolk/lokomotive-kubernetes-private.git//packet/flatcar-linux/kubernetes/workers"

  providers = {
    local    = "local.default"
    template = "template.default"
    tls      = "tls.default"
    packet   = "packet.default"
  }

  ssh_keys  = ["$${var.ssh_keys}"]

  cluster_name = "${var.cluster_name}"
  project_id   = "${var.packet_project_id}"
  facility     = "${var.facility}"

  pool_name = "workers"
  count     = "2"

  kubeconfig = "${module.packet-svc-mesh-benchmark.kubeconfig}"
}


provider "aws" {
  version = "~> 1.57.0"
  alias   = "default"

  region  = "eu-central-1"
}

provider "ct" {
  version = "~> 0.3"
}

provider "local" {
  version = "~> 1.0"
  alias   = "default"
}

provider "null" {
  version = "~> 1.0"
  alias   = "default"
}

provider "template" {
  version = "~> 1.0"
  alias   = "default"
}

provider "tls" {
  version = "~> 1.0"
  alias   = "default"
}

provider "packet" {
  version = "~> 1.2"
  alias = "default"

  auth_token = "${var.packet_auth_token}"
}
