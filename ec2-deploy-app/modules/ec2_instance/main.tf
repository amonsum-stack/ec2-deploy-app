variable "instance_type" {}
variable "ami_id" {}
variable "public_subnet_id" {}
variable "ec2_security_group_id" {}
variable "enable_public_ip_address" {}
variable "key_name" {} 

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
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name


  # user_data =  da se instlaira docker i da se pokrene container sa aplikacijom

  tags = {
    Name = "EC2 Deploy App Instance"
  }
}

data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "instance_role_secrets_manager" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = aws_iam_role.instance_role.name
} 

resource "aws_iam_role" "instance_role" {
  name               = "ec2_deploy_app_instance_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "ec2_deploy_app_instance_profile"
  role = aws_iam_role.instance_role.name
}

