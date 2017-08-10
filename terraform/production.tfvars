env = "production"

vpc_region = "us-east-1"

vpc_cidr = "10.10.0.0/16"

vpc_subnet_cidrs = {
  b = "10.10.0.0/17"
  d = "10.10.128.0/17"
}

controller_instance_type = "t2.micro"

controller_volume_size = 8

controller_ips = {
  b = "10.10.0.0"
  d = "10.10.128.0"
}

worker_instance_type = "t2.micro"

worker_volume_size = 8

worker_ips = {
  b = "10.10.0.1"
  d = "10.10.128.1"
}
