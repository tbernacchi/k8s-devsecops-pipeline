variable "domain_name" {
  type = string
}

variable "record_name" {
  type        = string
  description = "Nome do record (ex: app.exemplo.com ou exemplo.com)"
}

variable "create_zone" {
  type    = bool
  default = false
}

variable "existing_zone_id" {
  type    = string
  default = null
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
