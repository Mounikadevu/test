locals {
  name = var.name_prefix
  vpc_cidr_block = var.vpc_cidr_block
  public_cidrs = var.public_cidrs
  private_cidrs = var.private_cidrs
  azs = var.azs
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = local.name
  }
}

resource "aws_subnet" "public" {
  count                   = length(local.public_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(local.azs, count.index)
  tags = {
    Name = "${local.name}-public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count                   = length(local.private_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = element(local.azs, count.index)
  tags = {
    Name = "${local.name}-private-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Project VPC IG"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "Project VPC NAT"
  }

  depends_on = [
    aws_eip.nat_eip,
    aws_subnet.public[0]
  ]
}

resource "aws_route_table" "nat_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "nat_assoc" {
  count          = length(local.private_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.nat_route.id
}

resource "aws_security_group" "allow_http_https" {
  name        = "${local.name}-http-https"
  description = "Allow inbound traffic on ports 80 and 443"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_security_group_association" "public" {
  count      = length(local.public_cidrs)
  subnet_id  = aws_subnet.public[count.index].id
  security_group_id = aws_security_group.allow_http_https.id
}

# Application Load Balancer (ALB) Configuration
resource "aws_lb" "main" {
  name               = var.elb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_https.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = true

  tags = {
    Name = "${local.name}-alb"
  }

  depends_on = [
    aws_security_group.allow_http_https
  ]
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }

  depends_on = [
    aws_lb.main,
    aws_lb_target_group.front_end
  ]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }

  depends_on = [
    aws_lb.main,
    aws_lb_target_group.front_end
  ]
}

resource "aws_lb_target_group" "front_end" {
  name     = "${local.name}-front-end"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "front_end" {
  count = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = var.instance_ids[count.index]
  port             = 80
}

# Route 53 Hosted Zone and CNAME Record
resource "aws_route53_zone" "main" {
  name = var.zone_name
}

resource "aws_route53_record" "cname" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.main.dns_name]
}
