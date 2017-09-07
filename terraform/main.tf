# Root level cluster terraform file. All vars are environment specific, defined in <env>.tfvars

variable "env" {
  description = "One of dev/staging/production"
}

variable "vpc_region" {}
variable "vpc_cidr" {}

variable "vpc_subnet_cidrs" {
  type = "map"
}

variable "controller_instance_type" {}
variable "controller_volume_size" {}

variable "controller_ips" {
  type = "map"
}

variable "worker_instance_type" {}
variable "worker_volume_size" {}

variable "worker_ips" {
  type = "map"
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"

    shared_credentials_file = "/Users/brandono/.aws/credentials"
    profile                 = "bkubed"
  }
}

provider "aws" {
  version = "~> 0.1"

  region                  = "${var.vpc_region}"
  shared_credentials_file = "/Users/brandono/.aws/credentials"
  profile                 = "bkubed"
}

module "vpc" {
  source = "./modules/vpc"

  env          = "${var.env}"
  vpc_region   = "${var.vpc_region}"
  vpc_cidr     = "${var.vpc_cidr}"
  subnet_cidrs = "${var.vpc_subnet_cidrs}"

  ports = {
    ssh = 22
  }
}

module "controller_b" {
  source = "./modules/controller"

  env                = "${var.env}"
  ami_id             = "ami-cd0f5cb6"
  instance_type      = "${var.controller_instance_type}"
  subnet_id          = "${module.vpc.subnet_ids["b"]}"
  ssh_key_name       = "bkubed"
  security_group_ids = ["${module.vpc.ssh_security_group_id}", "${module.vpc.controller_security_group_id}"]
  volume_size        = "${var.controller_volume_size}"
  private_ip         = "${var.controller_ips["b"]}"
}

# module "controller_d" {
#   source = "./modules/controller"

#   env                = "${var.env}"
#   ami_id             = "ami-cd0f5cb6"
#   instance_type      = "${var.controller_instance_type}"
#   subnet_id          = "${module.vpc.subnet_ids["d"]}"
#   ssh_key_name       = "bkubed"
#   security_group_ids = ["${module.vpc.ssh_security_group_id}", "${module.vpc.controller_security_group_id}"]
#   volume_size        = "${var.controller_volume_size}"
#   private_ip         = "${var.controller_ips["d"]}"
# }

module "worker_b" {
  source = "./modules/worker"

  env                = "${var.env}"
  ami_id             = "ami-cd0f5cb6"
  instance_type      = "${var.worker_instance_type}"
  subnet_id          = "${module.vpc.subnet_ids["b"]}"
  ssh_key_name       = "bkubed"
  security_group_ids = ["${module.vpc.ssh_security_group_id}", "${module.vpc.worker_security_group_id}"]
  volume_size        = "${var.worker_volume_size}"
  private_ip         = "${var.worker_ips["b"]}"
}

# module "worker_d" {
#   source = "./modules/worker"


#   env                = "${var.env}"
#   ami_id             = "ami-cd0f5cb6"
#   instance_type      = "${var.worker_instance_type}"
#   subnet_id          = "${module.vpc.subnet_ids["d"]}"
#   ssh_key_name       = "bkubed"
#   security_group_ids = ["${module.vpc.ssh_security_group_id}", "${module.vpc.worker_security_group_id}"]
#   volume_size        = "${var.worker_volume_size}"
#   private_ip         = "${var.worker_ips["d"]}"
# }

