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

variable "cluster_name" {
  type    = string
  default = "devops-system-design-dev"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    a = { cidr = "10.20.0.0/24", az = "us-east-1a" }
    b = { cidr = "10.20.1.0/24", az = "us-east-1b" }
  }
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    a = { cidr = "10.20.10.0/24", az = "us-east-1a" }
    b = { cidr = "10.20.11.0/24", az = "us-east-1b" }
  }
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "devops-system-design"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
