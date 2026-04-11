output "cluster_name" {
  value = module.cluster.cluster_name
}

output "namespace_name" {
  value = module.cluster.namespace_name
}

output "backend_repository_url" {
  value = module.ecr.backend_repository_url
}

output "frontend_repository_url" {
  value = module.ecr.frontend_repository_url
}

output "backend_service_name" {
  value = module.backend_service.service_name
}

output "frontend_service_name" {
  value = module.frontend_service.service_name
}

output "frontend_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "frontend_alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "app_domain_name" {
  value = var.app_domain_name
}

output "route53_nameservers" {
  value = aws_route53_zone.main.name_servers
}
