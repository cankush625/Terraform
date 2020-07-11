provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
}

// Creating the EC2 private key
variable "key_name" {
  default = "Terraform_test_nfs"
}

resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
        command = "echo '${tls_private_key.ec2_private_key.private_key_pem}' > ~/Desktop/${var.key_name}.pem"            
    }
}

// Making the access of .pem key as a private
resource "null_resource" "key-perm" {
    depends_on = [
        tls_private_key.ec2_private_key,
    ]

    provisioner "local-exec" {
        command = "chmod 400 ~/Desktop/${var.key_name}.pem"
    }
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = var.key_name
  public_key = tls_private_key.ec2_private_key.public_key_openssh
}

resource "aws_vpc" "myVpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }

  enable_dns_hostnames = true;
}

resource "aws_subnet" "mySubnet1" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  vpc_id     = "${aws_vpc.myVpc.id}"
  cidr_block = "192.168.0.0/24"

  availability_zone = "ap-south-1a"

  tags = {
    Name = "my-subnet1"
  }

  map_public_ip_on_launch = true;
}

resource "aws_subnet" "mySubnet2" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  vpc_id     = "${aws_vpc.myVpc.id}"
  cidr_block = "192.168.1.0/24"

  availability_zone_id = "ap-south-1a"

  tags = {
    Name = "my-subnet2"
  }
}

resource "aws_internet_gateway" "myInternetGateway" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  vpc_id = "${aws_vpc.myVpc.id}"

  tags = {
    Name = "my-internet-gateway"
  }
}

resource "aws_route_table" "myRouteTable" {
  depends_on = [
    aws_vpc.myVpc,
    aws_internet_gateway.myInternetGateway,
  ]

  vpc_id = "${aws_vpc.myVpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myInternetGateway.id}"
  }

  tags = {
    Name = "my-route-table"
  }
}

resource "aws_route_table_association" "associateRouteTableWithSubnet" {
  depends_on = [
    aws_subnet.mySubnet1,
    aws_route_table.myRouteTable,
  ]
  subnet_id      = aws_subnet.mySubnet1.id
  route_table_id = aws_route_table.myRouteTable.id
}