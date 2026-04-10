variable "family" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_port" {
  type = number
}

variable "port_name" {
  type = string
}

variable "image" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "secrets" {
  type    = map(string)
  default = {}
}

variable "log_group_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "enable_execute_command" {
  type    = bool
  default = true
}

variable "wait_for_steady_state" {
  type    = bool
  default = true
}

variable "health_check" {
  type = object({
    command      = list(string)
    interval     = number
    timeout      = number
    retries      = number
    start_period = number
  })
  default = null
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = null
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "service_connect" {
  type = object({
    namespace_arn         = string
    discovery_name        = string
    client_alias_dns_name = string
    client_alias_port     = number
  })
  default = null
}
