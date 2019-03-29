
variable "aws_access_key" {
    type = "string"
     default = "AKIAJEY6VVM75KKLULRA"
}
variable "aws_secret_key" {
    type = "string"
    default = "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"
}

/* Start variables for vpc-build-config */
variable "name" {
    default = "aviatrix"
    description = "Name to be used on all the resources as identifier"
}
variable "cidr" {
  description = "Enter the CIDR Block for the VPC"
  default = "10.89.52.0/24"

}

variable "public_subnet" {
  type = "list"
  description = "Public subnets inside the VPC"
  default = ["10.89.52.0/26", "10.89.52.64/26"]
}

variable "azs" {
  type = "list"
  description = "A list of availability zones in the region"
  default = ["us-east-1a", "us-east-1b"]
}


variable "aws_account_id" {
  default = "209178370310"
}

variable "access_account_name" {
  default = "ICNS_Avrtx-Devops"
}

variable "admin_email" {
  default = "adal.andrade@teradata.com"
}

/* the new admin password */
variable "admin_password" {
  default = "T3r@D@t@2019"
}

/* Start Variables for Aviatrix-Controller-Build */

variable "vpc" {
  default = "aviatrix-vpc"
}
variable "subnet" {
  default = "10.89.52.0/26"
}

variable "keypair" {
  default = "mytfkeypair"
}

variable "ec2role" {
  default = "aviatrix-role-ec2"
}


terraform {
  backend "s3" {
    encrypt = true
    bucket = "avtrx-state"
    dynamodb_table = "my-avtrx-lock-table"
    region = "us-east-1"
    key = "terraform.state"
    access_key = "AKIAJEY6VVM75KKLULRA"
    secret_key = "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"

    }
}



provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}




data "aws_caller_identity" "current" {}

#Need to use this module if the controller is deployed for the first time
#module "aviatrix-controller-iam-roles" {
#  source = "./aviatrix-controller-iam-roles"
#  master-account-id = "${data.aws_caller_identity.current.account_id}"
#}


#module "terraform_state_backend" {
#  source        = "./terraform-aws-tfstate-backend"
#  namespace     = "cp"
#  stage         = "prod"
#  name          = "terraform"
#  attributes    = ["state"]
#  region        = "us-east-1"
#}







module "vpc-build-config" {
    source = "./vpc-build-config"
    cidr           = "${var.cidr}"
    public_subnet  = "${var.public_subnet}"
    name           = "${var.name}"
    azs            =  ["us-east-1a", "us-east-1b"]

}

module "aviatrix-controller-build" {
    source = "./aviatrix-controller-build"
    vpc = "${module.vpc-build-config.vpc_id}"
    subnet = "${module.vpc-build-config.subnet_ids[0]}"
    keypair = "mytfkeypair"
    ec2role = "aviatrix-role-ec2"
    
#    Uncomment the below line and remove the line 18, when using the script for the first time
#    ec2role = "${module.aviatrix-controller-iam-roles.aviatrix-role-ec2-name}"
}

module "aviatrix-controller-initialize" {
    source = "./aviatrix-controller-initialize"
    admin_password = "${var.admin_password}"
    admin_email    = "${var.admin_email}"
    private_ip     = "${module.aviatrix-controller-build.private_ip}"
    public_ip      = "${module.aviatrix-controller-build.public_ip}"
    aws_account_id = "${var.aws_account_id}"
    access_account_name = "${var.access_account_name}"
}

output "controller_private_ip" {
    value="${module.aviatrix-controller-build.private_ip}"
}

output "controller_public_ip" {
    value="${module.aviatrix-controller-build.public_ip}"
}
output "vpc_id" {
    value="${module.vpc-build-config.vpc_id}"
}

#output "subnet_ids" {
#    value="${module.vpc-build-config.subnet_ids}"
#}

