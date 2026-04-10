locals {
  environment_list = [
    for key, value in var.environment : {
      name  = key
      value = value
    }
  ]

  secrets_list = [
    for key, value in var.secrets : {
      name      = key
      valueFrom = value
    }
  ]

  container_base = {
    name      = var.container_name
    image     = var.image
    essential = true
    portMappings = [
      {
        name          = var.port_name
        containerPort = var.container_port
        protocol      = "tcp"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = local.environment_list
    secrets     = local.secrets_list
  }

  container_definition = merge(
    local.container_base,
    var.health_check == null ? {} : {
      healthCheck = {
        command     = var.health_check.command
        interval    = var.health_check.interval
        timeout     = var.health_check.timeout
        retries     = var.health_check.retries
        startPeriod = var.health_check.start_period
      }
    }
  )
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = jsonencode([local.container_definition])
  tags                     = var.tags
}

resource "aws_ecs_service" "this" {
  name                   = var.service_name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = var.enable_execute_command
  wait_for_steady_state  = var.wait_for_steady_state

  health_check_grace_period_seconds = var.target_group_arn == null ? null : var.health_check_grace_period_seconds

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]

    content {
      target_group_arn = load_balancer.value
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.service_connect == null ? [] : [var.service_connect]

    content {
      enabled   = true
      namespace = service_connect_configuration.value.namespace_arn

      service {
        discovery_name = service_connect_configuration.value.discovery_name
        port_name      = var.port_name

        client_alias {
          dns_name = service_connect_configuration.value.client_alias_dns_name
          port     = service_connect_configuration.value.client_alias_port
        }
      }
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = var.tags
}
