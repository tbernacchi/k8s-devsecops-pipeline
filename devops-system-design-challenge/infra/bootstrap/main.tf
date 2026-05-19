terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  # Facilita alternar entre AWS real e emuladores (ex: LocalStack/FLOCI).
  access_key                  = var.aws_access_key_id
  secret_key                  = var.aws_secret_access_key
  skip_credentials_validation = var.aws_skip_credentials_validation
  skip_metadata_api_check     = var.aws_skip_metadata_api_check
  skip_requesting_account_id  = var.aws_skip_requesting_account_id
  s3_use_path_style           = var.aws_s3_use_path_style

  endpoints {
    s3       = var.aws_endpoints.s3
    dynamodb = var.aws_endpoints.dynamodb
    iam      = var.aws_endpoints.iam
    sts      = var.aws_endpoints.sts
    ecr      = var.aws_endpoints.ecr
    eks      = var.aws_endpoints.eks
    ec2      = var.aws_endpoints.ec2
    route53  = var.aws_endpoints.route53
    acm      = var.aws_endpoints.acm
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}
