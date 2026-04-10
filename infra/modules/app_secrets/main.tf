resource "aws_secretsmanager_secret" "nvidia_api_key" {
  name                    = "${var.environment}/${var.project_name}/nvidia_api_key"
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-nvidia-api-key"
  })
}

resource "aws_secretsmanager_secret_version" "nvidia_api_key" {
  secret_id     = aws_secretsmanager_secret.nvidia_api_key.id
  secret_string = var.nvidia_api_key
}
