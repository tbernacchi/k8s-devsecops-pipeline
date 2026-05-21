variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "aws_access_key_id" {
  type    = string
  default = null
}

variable "aws_secret_access_key" {
  type    = string
  default = null
}

variable "aws_skip_credentials_validation" {
  type    = bool
  default = false
}

variable "aws_skip_metadata_api_check" {
  type    = bool
  default = false
}

variable "aws_skip_requesting_account_id" {
  type    = bool
  default = false
}

variable "aws_s3_use_path_style" {
  type    = bool
  default = false
}

variable "aws_endpoints" {
  description = "Endpoints customizados para provedores AWS-like (LocalStack/FLOCI)"
  type = object({
    s3       = optional(string)
    dynamodb = optional(string)
    iam      = optional(string)
    sts      = optional(string)
    ecr      = optional(string)
    eks      = optional(string)
    ec2      = optional(string)
    route53  = optional(string)
    acm      = optional(string)
  })
  default = {}
}

variable "state_bucket_name" {
  type = string
}

variable "lock_table_name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "terraform"
    Scope     = "bootstrap"
  }
}
