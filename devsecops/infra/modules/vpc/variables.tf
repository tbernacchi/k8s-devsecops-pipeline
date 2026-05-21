variable "name" {
  type        = string
  description = "Prefixo de nome para recursos da VPC"
}

variable "cluster_tag" {
  type        = string
  description = "Nome do cluster EKS para tags de subnet"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR principal da VPC"
}

variable "public_subnets" {
  description = "Mapa de subnets publicas"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "Mapa de subnets privadas"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
