locals {
  gateway_port = 8080
}

resource "aws_security_group" "lb_sg" {
  name   = "allow-http"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_alb" "api_alb" {
  name               = "gateway-alb"
  internal           = false
  load_balancer_type = "application"
  // TODO: remove cluster subnet
  subnets         = [aws_subnet.gateway.id, aws_subnet.cluster.id]
  security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "gateway" {
  name        = "gateway"
  port        = local.gateway_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
}


resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_alb.api_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }
}

resource "aws_lb_target_group_attachment" "gateway" {
  count            = length(aws_instance.gateway)
  target_group_arn = aws_lb_target_group.gateway.arn
  target_id        = aws_instance.gateway[count.index].id
}
