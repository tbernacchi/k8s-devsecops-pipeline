variable "project_name" {
  type    = string
  default = "devops-system-design"
}

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

variable "account_id" {
  type = string
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "github_allowed_subs" {
  type = list(string)
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
    Project     = "devops-system-design"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
