import {
  to = aws_ecr_repository.app
  id = "expense-tracker"
}

import {
  to = aws_ecs_cluster.main
  id = "expense-tracker"
}

import {
  to = aws_cloudwatch_log_group.app
  id = "/ecs/expense-tracker-web"
}

import {
  to = aws_security_group.web
  id = "sg-08518bc98348e9300"
}

import {
  to = aws_vpc_security_group_ingress_rule.http
  id = "sgr-014c327923f376c80"
}

import {
  to = aws_vpc_security_group_ingress_rule.app_from_self
  id = "sgr-08047a276a7ccdd30"
}

import {
  to = aws_vpc_security_group_egress_rule.all
  id = "sgr-0c695b2ec1599849f"
}
