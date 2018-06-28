// The name of the AWS profile to use
variable "aws_profile" {}

// The AWS region to create resources in
variable "aws_region" {
  default = "ap-southeast-1"
}

variable "slack_webhook" {}
