variable "vpc_id" {
  description = "VPC ID where the bastion host will be placed"
}

variable "public_subnet_id" {
  description = "Public subnet ID for the bastion host"
}

variable "ami_id" {
  description = "AMI ID for the bastion host"
}

variable "key_name" {
  description = "Key pair name for SSH access"
}

# Fetch the current IP to restrict SSH access
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Dedicated security group for the bastion — SSH from your IP only
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "SSH access to bastion host from operator IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Bastion EC2 instance 
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = {
    Name = "bastion-host"
    Role = "bastion"
  }
}

output "bastion_sg_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host — use this to SSH in"
  value       = aws_instance.bastion.public_ip
}
