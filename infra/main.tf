# The image registry from AWS Lesson 3
resource "aws_ecr_repository" "app" {
  name = "expense-tracker"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# The cluster from AWS Lesson 4
resource "aws_ecs_cluster" "main" {
  name = "expense-tracker"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

# Where the container's logs go
resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/expense-tracker-web"
}

# Look up the default VPC instead of hard-coding its ID
data "aws_vpc" "default" {
  default = true
}

# The security group, with each rule as its own resource
resource "aws_security_group" "web" {
  name        = "expense-tracker-web"
  description = "allows for access to expense tracking"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_self" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
