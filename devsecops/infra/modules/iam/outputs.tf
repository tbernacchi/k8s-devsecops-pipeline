output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_instance_profile_name" {
  value = aws_iam_instance_profile.node.name
}

output "ecr_pull_policy_arn" {
  value = aws_iam_policy.ecr_pull.arn
}
