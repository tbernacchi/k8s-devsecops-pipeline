variable "repositories" {
  type        = list(string)
  description = "Lista de repositorios ECR"
  default     = ["frontend", "backend"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
