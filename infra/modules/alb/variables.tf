variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "frontend_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}
