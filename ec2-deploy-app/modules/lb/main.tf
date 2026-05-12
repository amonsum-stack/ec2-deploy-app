variable "vpc_id" {}
variable "security_group_id" {}
variable "lb_name" {}
variable "lb_type" {}
variable "public_subnet_id" {}



resource "aws_lb" "app_lb" {
  name               = var.lb_name
  internal           = false
  load_balancer_type = var.lb_type
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_id

  tags = {
    Name = "app-lb"
  }
}

output "lb_arn" {
  value = aws_lb.app_lb.arn
}

