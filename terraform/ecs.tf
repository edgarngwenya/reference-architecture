resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name = "${var.environment_name}-${var.application_name}-log-group"
  retention_in_days = 30

  tags = {
    Environment = var.environment_name
    Application = var.application_name
  }
}

data "aws_iam_policy_document" "ecs-tasks-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "execution-policy" {
  name = "${var.environment_name}-${var.application_name}-execution-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecs:CreateCluster", "ecs:DeregisterContainerInstance", "ecs:DiscoverPollEndpoint",
        "ecs:Poll", "ecs:RegisterContainerInstance", "ecs:StartTelemetrySession",
        "ecs:UpdateContainerInstancesState", "ecs:Submit*", "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
        "logs:CreateLogStream", "logs:PutLogEvents",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "kms:Decrypt"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "execution_role" {
  name = "${var.environment_name}-${var.application_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-tasks-assume-role-policy.json
}

resource "aws_iam_policy_attachment" "execution_role_attachment" {
  name = "${var.environment_name}-${var.application_name}-excution-role-attachment"
  roles = [aws_iam_role.execution_role.name]
  policy_arn = aws_iam_policy.execution-policy.arn
}

resource "aws_ecs_task_definition" "task_definition" {
  family = var.application_name
  cpu = 2048
  memory = "4096"
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  execution_role_arn = aws_iam_role.execution_role.arn
  container_definitions = <<TASK_DEFINITIONS
[
  {
    "name": "${var.application_name}",
    "essential": true,
    "image": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/express:${var.build_id}",
    "portMappings": [ { "ContainerPort": ${var.docker_port_number} } ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.cloudwatch_log_group.name}",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "${var.application_name}"
      }
    },
    "environment": [
      {
        "name": "PORT",
        "value": "${var.docker_port_number}"
      }
    ],
    "secrets": [{
      "name": "MONGODB_URL",
      "valueFrom": "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment_name}/${var.application_name}/mongodbUrl"
    }]
  }
]
TASK_DEFINITIONS
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.application_name
}

resource "aws_security_group" "load_balancer_security_group" {
  name = "${var.environment_name}-${var.application_name}-load-balancer-sg"
  description = "Security Group for ${var.environment_name} ${var.application_name} Load Balancer"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow HTTPS/443 from anywhere"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }

  ingress {
    description = "Allow HTTP/80 from anywhere"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "container_security_group" {
  name = "${var.environment_name}-${var.application_name}-container-sg"
  description = "Security Group for ${var.environment_name} ${var.application_name} Container"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow Port ${var.docker_port_number}  from the Load Balancer"
    from_port = var.docker_port_number
    to_port = var.docker_port_number
    protocol = "tcp"
    security_groups = [ aws_security_group.load_balancer_security_group.id ]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "load_balancer" {
  name = "${var.environment_name}-${var.application_name}-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.load_balancer_security_group.id]
  subnets = aws_subnet.public_subnets.*.id
}

resource "aws_lb_listener" "load_balancer_http_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      port = 443
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "target_group" {
  name = "${var.environment_name}-${var.application_name}-target-group"
  vpc_id = aws_vpc.vpc.id
  port = var.docker_port_number
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    protocol = "HTTP"
    path = "/"
    interval = 10
    timeout = 5
    matcher = "200,301"
  }
}

resource "aws_lb_listener" "load_balancer_https_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port = 443
  protocol = "HTTPS"
  certificate_arn = var.certificate_arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_ecs_service" "ecs_service" {
  name = "${var.environment_name}-${var.application_name}"
  depends_on = [aws_lb.load_balancer, aws_lb_listener.load_balancer_https_listener]
  cluster = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  launch_type = "FARGATE"
  scheduling_strategy = "REPLICA"
  desired_count = 1
  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds = 60

  load_balancer {
    container_name = var.application_name
    container_port = var.docker_port_number
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  network_configuration {
    subnets = aws_subnet.private_subnets.*.id
    security_groups = [aws_security_group.container_security_group.id]
  }
}

resource "aws_route53_record" "route_53" {
  zone_id = var.host_zone_id
  name = "${var.environment_name}-${var.application_name}."
  type = "CNAME"
  records = [ aws_lb.load_balancer.dns_name]
  ttl = 900
}
