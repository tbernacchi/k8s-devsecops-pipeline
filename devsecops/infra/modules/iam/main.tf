data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_allowed_subs
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  tags               = var.tags
}

resource "aws_iam_policy" "s3_state" {
  name        = "${var.name}-tf-state-s3-policy"
  description = "Permissoes para bucket de state do Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.state_bucket_name}"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["arn:aws:s3:::${var.state_bucket_name}/*"]
      }
    ]
  })
}

resource "aws_iam_policy" "dynamodb_lock" {
  name        = "${var.name}-tf-lock-dynamodb-policy"
  description = "Permissoes para lock table do Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = ["arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.lock_table_name}"]
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_pull" {
  name        = "${var.name}-ecr-pull-policy"
  description = "Permissoes de pull no ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_s3" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_state.arn
}

resource "aws_iam_role_policy_attachment" "github_lock" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.dynamodb_lock.arn
}

resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-eks-node-profile"
  role = aws_iam_role.node.name
}
