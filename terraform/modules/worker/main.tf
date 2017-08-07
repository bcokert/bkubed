variable "env" {}
variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}

variable "ssh_key_name" {
  description = "The name in aws of the keypair to use"
}

variable "security_group_ids" {
  description = "Must be ids within a vpc"
  type        = "list"
}

variable "volume_size" {
  description = "size of the ssd in gigabytes"
}

resource "aws_instance" "worker" {
  ami                    = "${var.ami_id}"
  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${var.security_group_ids}"]
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.ssh_key_name}"

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.volume_size}"
  }

  tags {
    Name = "bkubed-${var.env}-worker"
  }
}

resource "aws_eip" "worker" {
  vpc                       = true
  instance                  = "${aws_instance.worker.id}"
  associate_with_private_ip = "${aws_instance.worker.private_ip}"
}
