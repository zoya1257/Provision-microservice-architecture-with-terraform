resource "aws_security_group" "browse_sg" {
  name        = "browse-sg"
  description = "Allow web traffic to browse EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb_sg.id] # App ALB se aane wali traffic allow
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BrowseSG"
  }
}

resource "aws_instance" "browse_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.browse_sg.id]
  associate_public_ip_address = false
  key_name                    = "keypair1" # Replace with your actual key

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt update -y
              apt install apache2 -y
              echo "<h1>Welcome to Browse Microservice</h1>" > /var/www/html/index.html
              systemctl restart apache2
          EOF
  )

  tags = {
    Name = "BrowseMicroservice"
  }
}

