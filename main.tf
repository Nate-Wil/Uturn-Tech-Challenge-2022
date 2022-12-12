resource "aws_vpc" "pyapp_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }

}

resource "aws_subnet" "pyapp_public_subnet-a" {
  vpc_id                  = aws_vpc.pyapp_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "dev-public-a"
  }
}

resource "aws_subnet" "pyapp_public_subnet-b" {
  vpc_id                  = aws_vpc.pyapp_vpc.id
  cidr_block              = "10.123.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"

  tags = {
    Name = "dev-public-b"
  }
}

resource "aws_internet_gateway" "pyapp_internet_gateway" {
  vpc_id = aws_vpc.pyapp_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "pyapp_public_rt" {
  vpc_id = aws_vpc.pyapp_vpc.id

  tags = {
    Name = "dev-public-rt"
  }

}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.pyapp_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.pyapp_internet_gateway.id

}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.pyapp_public_subnet-a.id
  route_table_id = aws_route_table.pyapp_public_rt.id

}

resource "aws_route_table_association" "public-b" {
  subnet_id      = aws_subnet.pyapp_public_subnet-b.id
  route_table_id = aws_route_table.pyapp_public_rt.id

}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.pyapp_vpc.id

  ingress {
    description = "HTTP"
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

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Ec2 Sg"
  vpc_id      = aws_vpc.pyapp_vpc.id

  ingress {
    description     = "ALB SG Allow for EC2"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "all for port 8000"
    from_port   = 8000
    to_port     = 8000
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


resource "aws_key_pair" "pyapp_auth" {
  key_name   = "pyappkey"
  public_key = file("~/.ssh/pyappkey.pub")
}

resource "aws_instance" "pyapp_node_a" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.server_ami.id


  key_name               = aws_key_pair.pyapp_auth.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.pyapp_public_subnet-a.id
  user_data              = file("userdata.tpl")
  iam_instance_profile   = aws_iam_instance_profile.node_a_profile.name
  tags = {
    Name = "pyapp-node-a"
  }
}

resource "aws_instance" "pyapp_node_b" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.server_ami.id


  key_name               = aws_key_pair.pyapp_auth.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.pyapp_public_subnet-b.id
  user_data              = file("userdata.tpl")
  iam_instance_profile   = aws_iam_instance_profile.node_b_profile.name
  tags = {
    Name = "pyapp-node-b"
  }

}

resource "aws_lb" "pyapp_lb" {
  name            = "pyapp-loadbalancer"
  security_groups = [aws_security_group.alb_sg.id]
  subnets         = [aws_subnet.pyapp_public_subnet-a.id, aws_subnet.pyapp_public_subnet-b.id]
  idle_timeout    = 400
}

resource "aws_lb_target_group" "pyapp_tg" {
  name     = "pyapp-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.pyapp_vpc.id
  health_check {

    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

}

resource "aws_lb_listener" "pyapp_front" {
  load_balancer_arn = aws_lb.pyapp_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pyapp_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "pyapp_tg_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.pyapp_tg.arn
  target_id        = aws_instance.pyapp_node_a.id
  port             = 8000
}


