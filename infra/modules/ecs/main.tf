
#  VARIABLES

variable "project" {
     type = string 
    default = "signalfind" 
    }
variable "env"     { type = string }
variable "region"  { 
    type = string 
    default = "ap-southeast-2" 
    }

variable "vpc_id" { type = string }

# ALB goes here
variable "public_subnet_ids" { type = list(string) }

# ECS Tasks go here
variable "private_subnet_ids" { type = list(string) }

variable "desired_count" { 
    type = number 
    default = 2 
    }
variable "cpu"           { 
    type = number 
    default = 256 
    }
variable "memory"        { 
    type = number 
    default = 512 
    }

variable "container_image" { type = string }
variable "container_port"  { 
    type = number 
    default = 8080 
    }


#  ECS CLUSTER

resource "aws_ecs_cluster" "this" {
  name = "${var.project}-${var.env}-cluster"
}


#  CLOUDWATCH LOG GROUP

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project}/${var.env}/api"
  retention_in_days = 30
}


#  SECURITY GROUPS


# ALB SG – internet -> ALB
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.env}-alb-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service SG – ALB -> ECS
resource "aws_security_group" "svc" {
  name        = "${var.project}-${var.env}-ecs-sg"
  description = "Allow ALB to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#  APPLICATION LOAD BALANCER (PUBLIC)

resource "aws_lb" "alb" {
  name               = "${var.project}-${var.env}-alb"
  internal           = false                 # PUBLIC ALB
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids #  Use PUBLIC SUBNETS
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project}-${var.env}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}


# IAM ROLES

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.project}-${var.env}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.project}-${var.env}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}


#  ECS TASK DEFINITION

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-${var.env}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = var.container_image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}


#  ECS SERVICE

resource "aws_ecs_service" "api" {
  name            = "${var.project}-${var.env}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids    # ECS tasks in PRIVATE subnets
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}

#  OUTPUTS

output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "cluster_name" { value = aws_ecs_cluster.this.name }
