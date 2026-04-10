resource "aws_service_discovery_private_dns_namespace" "this" {
  name = var.namespace_name
  vpc  = var.vpc_id

  tags = merge(var.tags, {
    Name = var.namespace_name
  })
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.this.arn
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}
