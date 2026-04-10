output "nvidia_api_key_secret_arn" {
  value = aws_secretsmanager_secret.nvidia_api_key.arn
}
