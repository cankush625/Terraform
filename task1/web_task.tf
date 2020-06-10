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

resource "aws_key_pair" "deploy" {
  key_name   = "Terraform_test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiZ55KAl3LlJBet3VNzdPaPLTJSM7ikCsUeKRGmqkk1K0MXlLgE2cfaVoBuFmm4c0U62M4YEU/qm3JJdVsttGOOpx4FRb++U8xaJgPvKpxUGk9/ZaFGPQiIr1t1Cfj1uZiQSXADMdFTF4175fwYgfJMcRkJmi7XLJexTZQrSH8phts1jhuF2YlsvzjYv5OK39iwn9guyU+tC1ThR1iVZxhsd08kp81ThypFisaVYLCC2qf5NFR2tj/yBfehmMpCPSKIQTpJzYlRPZufju3yY3AlWJuuJkX8blRGUpchuERuorcDPVC5EFVA3V4LAlNDGXaUx1j6Wan7KhyuulhsmPtXgtfH+pboWKt4yz4ydoQ7A7Dub1g3vcvLxkYXp+Kmgco6Ni3mXoYhWxbCBXSFXflSfJx9aMugHrGKALZZd210xC/7AT+UutDRX6ya/y2vgZKvrAVCefetjgUth0ZpA5KyOMpcJMtJzEFRp8siL2VC2FDwkX+bdys5wKQ6igO6fxPTAmyR2B/v0a+Zq7LByWNteh22KLf/EUjcWwxfjgA+QHujHf850sDOI31Z2bz1RubuTtLaA4tpNgnpVhcRxAfCRrXVTcNIqUGxZzFQE7B2SQr49ZG0o5xP8YQc2iytcxhP0YCFFd4flO73qyiltSS/lNQxLvsk3XuWIWHVmH1/w=="
}

// Creating aws security resource
resource "aws_security_group" "allow_tcp" {
  name        = "allow_tcp"
  description = "Allow TCP inbound traffic"
  //vpc_id      = "vpc-4ae4f922"

  ingress {
    description = "TLS from VPC"
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
}