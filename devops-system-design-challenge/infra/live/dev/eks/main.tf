terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    # Preencha com bucket/key/region/dynamodb_table reais
    bucket         = "TODO-terraform-state-bucket"
    key            = "dev/eks/terraform.tfstate"
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

module "vpc" {
  source = "../../../modules/vpc"

  name            = var.project_name
  cluster_tag     = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  tags            = var.tags
}

module "eks" {
  source = "../../../modules/eks"

  name                = var.project_name
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  cluster_role_arn    = var.cluster_role_arn
  node_role_arn       = var.node_role_arn
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = var.tags
}
