locals {
  cluster_name          = "${var.environment}-${var.project_name}-cluster"
  namespace_name        = "${var.environment}-${var.project_name}"
  backend_service_name  = "${var.environment}-backend-service"
  frontend_service_name = "${var.environment}-frontend-service"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_route53_zone" "main" {
  name = var.hosted_zone_name

  tags = merge(local.common_tags, {
    Name = var.hosted_zone_name
  })
}

resource "aws_acm_certificate" "app" {
  domain_name       = var.app_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = var.app_domain_name
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

module "default_network" {
  source = "../../modules/default_network"
}

module "app_secrets" {
  source         = "../../modules/app_secrets"
  environment    = var.environment
  project_name   = var.project_name
  nvidia_api_key = var.nvidia_api_key
  tags           = local.common_tags
}

module "ecr" {
  source       = "../../modules/ecr"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

module "iam" {
  source       = "../../modules/iam"
  environment  = var.environment
  project_name = var.project_name
  secret_arns  = [module.app_secrets.nvidia_api_key_secret_arn]
  tags         = local.common_tags
}

module "cluster" {
  source         = "../../modules/ecs_cluster"
  cluster_name   = local.cluster_name
  namespace_name = local.namespace_name
  vpc_id         = module.default_network.vpc_id
  tags           = local.common_tags
}

module "security_groups" {
  source        = "../../modules/service_security_groups"
  environment   = var.environment
  project_name  = var.project_name
  vpc_id        = module.default_network.vpc_id
  frontend_port = 80
  backend_port  = 8000
  tags          = local.common_tags
}

module "alb" {
  source                = "../../modules/alb"
  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.default_network.vpc_id
  public_subnet_ids     = module.default_network.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_sg_id
  frontend_port         = 80
  health_check_path     = "/health"
  certificate_arn       = aws_acm_certificate_validation.app.certificate_arn
  tags                  = local.common_tags
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

module "backend_service" {
  source             = "../../modules/ecs_service"
  family             = "${local.backend_service_name}-task"
  service_name       = local.backend_service_name
  cluster_arn        = module.cluster.cluster_arn
  container_name     = "backend-container"
  container_port     = 8000
  port_name          = "backend-8000"
  image              = "${module.ecr.backend_repository_url}:${var.backend_image_tag}"
  cpu                = var.backend_cpu
  memory             = var.backend_memory
  desired_count      = var.backend_desired_count
  subnet_ids         = module.default_network.public_subnet_ids
  security_group_ids = [module.security_groups.backend_service_sg_id]
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn
  log_group_name     = "/ecs/${local.cluster_name}/${local.backend_service_name}"
  aws_region         = var.aws_region
  tags               = local.common_tags

  environment = {
    ENVIRONMENT  = var.environment
    API_BASE_URL = "http://${local.backend_service_name}:8000"
  }

  secrets = {
    NVIDIA_API_KEY = module.app_secrets.nvidia_api_key_secret_arn
  }

  health_check = {
    command      = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
    interval     = 30
    timeout      = 5
    retries      = 3
    start_period = 60
  }

  service_connect = {
    namespace_arn         = module.cluster.namespace_arn
    discovery_name        = local.backend_service_name
    client_alias_dns_name = local.backend_service_name
    client_alias_port     = 8000
  }
}

module "frontend_service" {
  source             = "../../modules/ecs_service"
  family             = "${local.frontend_service_name}-task"
  service_name       = local.frontend_service_name
  cluster_arn        = module.cluster.cluster_arn
  container_name     = "frontend-container"
  container_port     = 80
  port_name          = "frontend-80"
  image              = "${module.ecr.frontend_repository_url}:${var.frontend_image_tag}"
  cpu                = var.frontend_cpu
  memory             = var.frontend_memory
  desired_count      = var.frontend_desired_count
  subnet_ids         = module.default_network.public_subnet_ids
  security_group_ids = [module.security_groups.frontend_service_sg_id]
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn
  log_group_name     = "/ecs/${local.cluster_name}/${local.frontend_service_name}"
  aws_region         = var.aws_region
  tags               = local.common_tags
  depends_on = [ module.alb ]

  environment = {
    ENVIRONMENT          = var.environment
    ECS_NAMESPACE        = module.cluster.namespace_name
    BACKEND_SERVICE_NAME = local.backend_service_name
  }

  health_check = {
    command      = ["CMD-SHELL", "curl -f http://localhost:80/health || exit 1"]
    interval     = 30
    timeout      = 5
    retries      = 3
    start_period = 60
  }

  health_check_grace_period_seconds = 60
  target_group_arn                  = module.alb.frontend_target_group_arn

  service_connect = {
    namespace_arn         = module.cluster.namespace_arn
    discovery_name        = local.frontend_service_name
    client_alias_dns_name = local.frontend_service_name
    client_alias_port     = 80
  }
}
