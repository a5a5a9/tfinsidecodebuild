
/* the private IP of the controller */
variable "private_ip" {}

/* the public IP of the controller */
variable "public_ip" {}
variable "admin_email" {}
variable "admin_password" {}

/* the controller account friendly name (mapping to the AWS account ID) */
variable "access_account_name" {}
/* aws account id */
variable "aws_account_id" {}

/* the controller account friendly name (mapping to the AWS account ID) */
variable "customer_license_id" {
  default = ""
}


terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}
  
}

data "aws_caller_identity" "current" {
   
}



resource "aws_iam_role" "iam_for_lambda" {
  name = "${replace("iam_for_lambda_${var.public_ip}",".","-")}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach-policy" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_region" "current" {}

resource "aws_lambda_function" "lambda" {
  s3_bucket     = "aviatrix-lambda-${data.aws_region.current.name}"
  s3_key        = "run_controller_init_setup.zip"
  function_name = "${replace("AvxLambda_${var.public_ip}",".","-")}"
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "run_controller_init_setup.lambda_handler"
  runtime       = "python3.7"
  description   = "MANAGED BY TERRAFORM"
  timeout       = 900
}

data "aws_lambda_invocation" "example" {
  function_name   = "${aws_lambda_function.lambda.function_name}"
  
  input = <<JSON
{ "ResourceProperties":
{
  "PrefixStringParam"                : "avx",
  "LambdaInvokerTypeParam"           : "terraform",
  "AWS_Account_ID"                   : "${var.aws_account_id}",
  "KeywordForCloudWatchLogParam"     : "avx-log",
  "DelimiterForCloudWatchLogParam"   : "---",
  "ControllerPublicIpParam"          : "${var.public_ip}",
  "AviatrixApiVersionParam"          : "v1",
  "AviatrixApiRouteParam"            : "api/",
  "ControllerPrivateIpParam"         : "${var.private_ip}",
  "ControllerAdminPasswordParam"     : "${var.admin_password}",
  "ControllerAdminEmailParam"        : "${var.admin_email}",
  "ControllerVersionParam"           : "latest",
  "ControllerAccessAccountNameParam" : "${var.access_account_name}",
  "AviatrixCustomerLicenseIdParam"   : "${var.customer_license_id}"
}
}
JSON
}


output "result" {
   value = "${data.aws_lambda_invocation.example.result}"
}
