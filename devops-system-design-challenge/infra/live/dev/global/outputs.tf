output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}

output "node_role_arn" {
  value = module.iam.node_role_arn
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}
