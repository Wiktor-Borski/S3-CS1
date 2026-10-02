terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# =========================
# VPC
# =========================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "innovatech-vpc"
    Environment = "cs1"
    Project     = "innovatech"
  }
}

# =========================
# Public subnets
# =========================

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "innovatech-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "innovatech-public-b"
    Tier = "public"
  }
}

# =========================
# Private web subnets
# =========================

resource "aws_subnet" "web_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "innovatech-web-a"
    Tier = "private-web"
  }
}

resource "aws_subnet" "web_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "innovatech-web-b"
    Tier = "private-web"
  }
}

# =========================
# Private database subnets
# =========================

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "innovatech-db-a"
    Tier = "private-db"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "innovatech-db-b"
    Tier = "private-db"
  }
}

# ---------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "innovatech-igw"
  }
}

# ---------------------------------------------------------
# Public Route Table
# ---------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "innovatech-public-rt"
    Tier = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "innovatech-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "innovatech-nat"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "innovatech-private-rt"
  }
}

resource "aws_route_table_association" "web_a" {
  subnet_id      = aws_subnet.web_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "web_b" {
  subnet_id      = aws_subnet.web_b.id
  route_table_id = aws_route_table.private.id
}


# ---------------------------------------------------------
# Public Subnet Associations
# ---------------------------------------------------------

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
# ---------------------------------------------------------
# Security Groups
# ---------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "innovatech-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for initial testing"
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

  tags = {
    Name = "innovatech-alb-sg"
    Tier = "public"
  }
}

resource "aws_security_group" "web" {
  name        = "innovatech-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-web-sg"
    Tier = "private-web"
  }
}

resource "aws_security_group" "db" {
  name        = "innovatech-db-sg"
  description = "Security group for MariaDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MariaDB only from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-db-sg"
    Tier = "private-db"
  }
}
# ---------------------------------------------------------
# RDS MariaDB
# ---------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name = "innovatech-db-subnet-group"
  subnet_ids = [
    aws_subnet.db_a.id,
    aws_subnet.db_b.id
  ]

  tags = {
    Name = "innovatech-db-subnet-group"
  }
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.db_a.id
  vpc_security_group_ids = [aws_security_group.db.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y mariadb105-server
              systemctl enable mariadb
              systemctl start mariadb
              EOF

  tags = {
    Name        = "innovatech-db"
    Project     = "innovatech"
    Environment = "cs1"
    Tier        = "private-db"
  }
}
resource "aws_launch_template" "web" {
  name_prefix   = "innovatech-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx

    systemctl enable nginx
    systemctl start nginx

    echo "<h1>Innovatech Web Server</h1><p>Hostname: $(hostname)</p>" > /usr/share/nginx/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "innovatech-web"
      Project     = "innovatech"
      Environment = "cs1"
      Tier        = "private-web"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name             = "innovatech-web-asg"
  min_size         = 2
  max_size         = 6
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.web_a.id,
    aws_subnet.web_b.id
  ]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "innovatech-web"
    propagate_at_launch = true
  }
}
resource "aws_lb" "web" {
  name               = "innovatech-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name        = "innovatech-web-alb"
    Project     = "innovatech"
    Environment = "cs1"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "innovatech-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "innovatech-web-tg"
  }
}

resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = aws_autoscaling_group.web.name
  lb_target_group_arn    = aws_lb_target_group.web.arn
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

output "alb_dns_name" {
  description = "DNS name of the Innovatech Application Load Balancer"
  value       = aws_lb.web.dns_name
}

resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "innovatech-web-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60.0
  }
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "innovatech-web-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"
  threshold   = 70

  alarm_description = "High CPU utilization on Innovatech web servers"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}