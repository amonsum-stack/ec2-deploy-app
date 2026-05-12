variable "instance_type" {}
variable "ami_id" {}
variable "public_subnet_id" {}
variable "ec2_security_group_id" {}
variable "enable_public_ip_address" {}
variable "key_name" {} 
variable "iam_instance_profile" {}



output "ec2_instance_id" {
  value = aws_instance.ec2_instance.id
}


# Create ec2 instance
resource "aws_instance" "ec2_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_security_group_id]
  associate_public_ip_address = var.enable_public_ip_address
  key_name = var.key_name
  iam_instance_profile = var.iam_instance_profile

user_data = <<-EOF
  #!/bin/bash
  dnf update -y
  dnf install -y docker
  systemctl start docker
  systemctl enable docker
  docker pull igior/weather-app:latest
  docker run -d \
    --name weather-app \
    --restart always \
    -p 8080:8080 \
    igior/weather-app:latest
EOF

  tags = {
    Name = "EC2 Deploy App Instance"
  }
}
