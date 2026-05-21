locals {
  repos = toset(var.repositories)
}

resource "aws_ecr_repository" "this" {
  for_each = local.repos

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = each.key
  })
}
