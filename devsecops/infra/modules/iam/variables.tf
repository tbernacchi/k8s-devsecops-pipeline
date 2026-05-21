variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "github_allowed_subs" {
  type        = list(string)
  description = "Subjects permitidos para o role do GitHub Actions"
}

variable "state_bucket_name" {
  type = string
}

variable "lock_table_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
