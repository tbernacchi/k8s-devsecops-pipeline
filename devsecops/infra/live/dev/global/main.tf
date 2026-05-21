terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    # Preencha com bucket/key/region/dynamodb_table reais
    bucket         = "TODO-terraform-state-bucket"
    key            = "dev/global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "TODO-terraform-locks"
    encrypt        = true
  }

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

module "ecr" {
  source = "../../../modules/ecr"

  repositories = ["frontend", "backend"]
  tags         = var.tags
}

module "iam" {
  source = "../../../modules/iam"

  name                     = var.project_name
  region                   = var.region
  account_id               = var.account_id
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_allowed_subs      = var.github_allowed_subs
  state_bucket_name        = var.state_bucket_name
  lock_table_name          = var.lock_table_name
  tags                     = var.tags
}

# O DNS depende do ALB criado para o cluster/aplicacoes.
# Mantenha este modulo comentado ate ter os outputs do ALB.
# module "dns" {
#   source = "../../../modules/dns"
#
#   domain_name      = var.domain_name
#   record_name      = var.record_name
#   create_zone      = var.create_zone
#   existing_zone_id = var.existing_zone_id
#   alb_dns_name     = var.alb_dns_name
#   alb_zone_id      = var.alb_zone_id
#   tags             = var.tags
# }
