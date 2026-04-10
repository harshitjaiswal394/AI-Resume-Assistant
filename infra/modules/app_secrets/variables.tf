variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "nvidia_api_key" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}
