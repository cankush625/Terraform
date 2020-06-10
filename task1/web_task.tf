// Configuring the provider information
provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
}

// Creating the EC2 private key
//variable "key_name" {}

resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "Terraform_test"
  public_key = tls_private_key.ec2_private_key.public_key_openssh
}

// Creating aws security resource
resource "aws_security_group" "allow_tcp" {
  name        = "allow_tcp"
  description = "Allow TCP inbound traffic"
  vpc_id      = "vpc-4ae4f922"

  ingress {
    description = "TCP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_tcp"
  }
}

// Launching new EC2 instance
resource "aws_instance" "myWebOS" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "Terraform_test"
    vpc_security_group_ids = ["${aws_security_group.allow_tcp.id}"]
    subnet_id = "subnet-2f0b3147"
    tags = {
        Name = "TeraTaskOne"
    }
    user_data = "${file("vol.sh")}"
}

// Creating EBS volume
resource "aws_ebs_volume" "myWebVol" {
  availability_zone = "ap-south-1a"
  size              = 1

  tags = {
    Name = "TeraTaskVol"
  }
}

// Attaching above volume to the EC2 instance
resource "aws_volume_attachment" "myWebVolAttach" {
  device_name = "/dev/sdc"
  volume_id = "${aws_ebs_volume.myWebVol.id}"
  instance_id = "${aws_instance.myWebOS.id}"
  skip_destroy = true
}

//
