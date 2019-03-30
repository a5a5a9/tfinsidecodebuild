provider "aws" {
#    access_key = "${var.aws_access_key}"
#    secret_key = "${var.aws_secret_key}"
    region     = "us-east-1"
}




data "aws_caller_identity" "current" {}


#data "aws_subnet" "selected" {
#  tags {
#    Name = "${var.subnet}"
#     Name = "aviatrix-public-us-east-1a"
#  }
#} 

variable "num_controllers" {
  default = 1
}
variable "vpc" {}

variable "subnet" {} 

variable "keypair" {}

variable "ec2role" {}


	


#
# Defaults
#

# This is the default root volume size as suggested by Aviatrix
variable "root_volume_size" {
  default = 16
}

variable "root_volume_type" {
  default = "standard"
}

variable "incoming_ssl_cidr" {
  type = "list"
  default = ["0.0.0.0/0"]
}

variable "instance_type" {
  default = "t2.micro"
}

variable "name_prefix" {
  default = ""
}

variable "type" {
  default = "metered"
}


terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}
  
}

data "aws_region" "current" {}

locals {
    name_prefix = "${var.name_prefix != "" ? "${var.name_prefix}-" : ""}"
    images_metered = {
        us-east-1 = "ami-df74f6a0"
        us-east-2 = "ami-a72c11c2"
        us-west-1 = "ami-e3170983"
        us-west-2 = "ami-1f770667"
        ca-central-1 = "ami-8d8707e9"
        eu-central-1 = "ami-d9bf9d32"
        eu-west-1 = "ami-f227138b"
        eu-west-2 = "ami-a06587c7"
        eu-west-3 = "ami-339e2f4e"
        ap-southeast-1 = "ami-8fcbfef3"
        ap-southeast-2 = "ami-e90ed98b"
        ap-northeast-1 = "ami-358f674a"
        ap-northeast-2 = "ami-cc08a1a2"
        ap-south-1 = "ami-ccc4e7a3"
        sa-east-1 = "ami-1a90cd76"
    }
    images_byol = {
        us-east-1 = "ami-db9bb9a1"
        us-east-2 = "ami-b40228d1"
        us-west-1 = "ami-2a7e7c4a"
        us-west-2 = "ami-fd48f885"
        ca-central-1 = "ami-de4bceba"
        eu-central-1 = "ami-a025b9cf"
        eu-west-1 = "ami-830d93fa"
        eu-west-2 = "ami-bc253ed8"
        eu-west-3 = "ami-f8e35585"
        ap-southeast-1 = "ami-0484f878"
        ap-southeast-2 = "ami-34728e56"
        ap-northeast-2 = "ami-d902a2b7"
        ap-northeast-1 = "ami-2a43244c"
        ap-south-1 = "ami-e7560088"
        sa-east-1 = "ami-404c012c"
        us-gov-west-1 = "ami-30890051"
    }
    ami_id = "${var.type == "metered" ? local.images_metered[data.aws_region.current.name] : local.images_byol[data.aws_region.current.name]}"
}

# data "aws_vpc" "aviatrix-vpc" {
#  tags {
#    Name = "${var.vpc}"
#  }
  
#}

resource "aws_security_group" "AviatrixSecurityGroup" {
  name        = "${local.name_prefix}AviatrixSecurityGroup"
  description = "Aviatrix - Controller Security Group"
#  vpc_id      = "${data.aws_vpc.aviatrix-vpc.id}"
  vpc_id = "${var.vpc}"

  tags {
    Name      = "${local.name_prefix}AviatrixSecurityGroup"
    Createdby = "Terraform+Aviatrix"
  }
}

resource "aws_security_group_rule" "ingress_rule" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = "${var.incoming_ssl_cidr}"
  security_group_id = "${aws_security_group.AviatrixSecurityGroup.id}"
}

resource "aws_security_group_rule" "egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.AviatrixSecurityGroup.id}"
}


resource "aws_eip" "controller_eip" {
  count = "${var.num_controllers}"
  vpc   = true
}

resource "aws_eip_association" "eip_assoc" {
  count         = "${var.num_controllers}"
  instance_id   = "${element(aws_instance.aviatrixcontroller.*.id, count.index)}"
  allocation_id = "${element(aws_eip.controller_eip.*.id, count.index)}"
}

resource "aws_network_interface" "eni-controller" {
  count     = "${var.num_controllers}"
  subnet_id = "${var.subnet}"
#  subnet_id =  "${element(data.aws_subnet.selected.id,count.index)}"
#  subnet_id =  "${data.aws_subnet.selected.id}"
  security_groups = ["${aws_security_group.AviatrixSecurityGroup.id}"]


  tags {
    Name      = "${format("%s%s : %d", local.name_prefix, "Aviatrix Controller interface", count.index)}"
    Createdby = "Terraform+Aviatrix"
  }
}

resource "aws_iam_instance_profile" "aviatrix-role-ec2_profile" {
  name = "${local.name_prefix}aviatrix-role-ec2_profile"
  role = "${var.ec2role}"
}

resource "aws_instance" "aviatrixcontroller" {
  count                = "${var.num_controllers}"
  ami                  = "${local.ami_id}"
  instance_type        = "${var.instance_type}"
  key_name             = "${var.keypair}"
  iam_instance_profile = "${var.ec2role}"
#  iam_instance_profile = "${aws_iam_instance_profile.aviatrix-role-ec2_profile.id}"

  network_interface {
    network_interface_id = "${element(aws_network_interface.eni-controller.*.id, count.index)}"
    device_index         = 0
  }

  root_block_device {
    volume_size = "${var.root_volume_size}"
    volume_type = "${var.root_volume_type}"
  }

  tags {
#    Name      = "${format("%s%s : %d", local.name_prefix, "AviatrixController", count.index)}"
    Name = "AviatrixController"
    Createdby = "Terraform+Aviatrix"
  }
}



output "private_ip" {
  value = "${aws_instance.aviatrixcontroller.*.private_ip[0]}"
}

output "public_ip" {
  value = "${aws_eip.controller_eip.*.public_ip[0]}"
}


