terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" { region = "us-east-1" }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Certificado Autoassinado
resource "tls_private_key" "lab_key" { algorithm = "RSA" }
resource "tls_self_signed_cert" "lab_cert" {
  private_key_pem = tls_private_key.lab_key.private_key_pem
  validity_period_hours = 8760
  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
  subject { common_name = "meulab.local" }
}
resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.lab_key.private_key_pem
  certificate_body = tls_self_signed_cert.lab_cert.cert_pem
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg_lab"
  description = "Permite HTTPS externo"
  ingress { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_k3s_sg_lab"
  description = "Permite trafego do ALB para a EC2"
  ingress { from_port = 80, to_port = 80, protocol = "tcp", security_groups = [aws_security_group.alb_sg.id] }
  egress  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

# Application Load Balancer
resource "aws_lb" "lab_alb" {
  name               = "lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "k3s_tg" {
  name     = "k3s-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lab_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_tg.arn
  }
}

# Instância EC2
resource "aws_instance" "k3s_node" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 em us-east-1
  instance_type = "t3.medium"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data     = file("userdata.sh")
  
  tags = { Name = "Lab-K3s-Server" }
}

resource "aws_lb_target_group_attachment" "attach_ec2" {
  target_group_arn = aws_lb_target_group.k3s_tg.arn
  target_id        = aws_instance.k3s_node.id
  port             = 80
}

output "url_acesso" {
  value = "https://${aws_lb.lab_alb.dns_name}"
  description = "Acesse suas aplicações por este link"
}