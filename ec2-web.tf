resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "keypair1" # 🔁 replace with your actual key pair name

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "<h1>Welcome to my Terraform Architecture</h1>" > /var/www/html/index.html
              apt update
              apt install -y apache2
              systemctl start apache2
              systemctl enable apache2
              EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg"
    propagate_at_launch = true
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300
}

