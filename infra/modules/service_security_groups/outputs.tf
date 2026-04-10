output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "frontend_service_sg_id" {
  value = aws_security_group.frontend_service.id
}

output "backend_service_sg_id" {
  value = aws_security_group.backend_service.id
}
