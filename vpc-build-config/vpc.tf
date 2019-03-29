data "aws_caller_identity" "current" {}

variable "name" {}

variable "cidr" {}

variable "public_subnet" {
  type = "list"
}
variable "azs" {
  type = "list"
# default = ["us-east-1a", "us-east-1b"]
}


terraform {
	backend "s3" {}
}



######
# VPC
######
resource "aws_vpc" "aviatrix_vpc" {
  cidr_block                       = "${var.cidr}"
  instance_tenancy                 = "default"
  tags = "${merge(map("Name", format("%s-vpc", var.name)))}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "aviatrix_vpc_igw" {
  vpc_id = "${aws_vpc.aviatrix_vpc.id}"
  tags = "${merge(map("Name", format("%s-igw", var.name)))}"
}

################
# Public route
################
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.aviatrix_vpc.id}"
  tags = "${merge(map("Name", format("%s-public", var.name)))}"
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.aviatrix_vpc_igw.id}"
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count                   = "2"
  vpc_id                  = "${aws_vpc.aviatrix_vpc.id}"
  cidr_block              = "${var.public_subnet[count.index]}"
  availability_zone       = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = "true"

  tags = "${merge(map("Name", format("%s-public-%s", var.name, element(var.azs, count.index))))}"
}


##########################
# Route table association
##########################
resource "aws_route_table_association" "public" {
   count          = "2"
   subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
   route_table_id = "${aws_route_table.public.id}"
}

output "vpc_id" {
    value="${aws_vpc.aviatrix_vpc.id}"
}
#output "subnet_id" {
#    value="${aws_subnet.public.0.id}"
#}
output "subnet_ids" {
    value="${aws_subnet.public.*.id}"
}