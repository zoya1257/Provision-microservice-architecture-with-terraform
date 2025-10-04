# ✅ Ubuntu AMI (Already declared somewhere in your code)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ✅ Security Group for App EC2
resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# ✅ Internal ALB Security Group
resource "aws_security_group" "internal_alb_sg" {
  name   = "internal-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internal-alb-sg"
  }
}

# ✅ Internal Application Load Balancer
resource "aws_lb" "internal_alb" {
  name               = "app-alb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = aws_subnet.private[*].id
}

# ✅ Target Group for Internal ALB
resource "aws_lb_target_group" "internal_app_tg" {
  name        = "internal-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ✅ Listener for Internal ALB
resource "aws_lb_listener" "internal_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_app_tg.arn
  }
}

# ✅ Launch Template for App EC2
resource "aws_launch_template" "app" {
  name_prefix   = "app-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "App Server Running" > /var/www/html/index.html
              apt update
              apt install -y apache2
              systemctl start apache2
              systemctl enable apache2
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AppServer"
    }
  }
}

# ✅ Auto Scaling Group for App Layer
resource "aws_autoscaling_group" "app" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.internal_app_tg.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "AppASG"
    propagate_at_launch = true
  }
}

# ✅ Output for Internal ALB DNS
output "internal_alb_dns_name" {
  value       = aws_lb.internal_alb.dns_name
  description = "Internal ALB DNS"
}

