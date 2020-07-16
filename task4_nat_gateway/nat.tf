provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
}

// Creating the EC2 private key
variable "key_name" {
  default = "Terraform_nat"
}

resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
        command = "echo '${tls_private_key.ec2_private_key.private_key_pem}' > ~/Desktop/task3/${var.key_name}.pem"            
    }
}

// Making the access of .pem key as a private
resource "null_resource" "key-perm" {
    depends_on = [
        tls_private_key.ec2_private_key,
    ]

    provisioner "local-exec" {
        command = "chmod 400 ~/Desktop/task3/${var.key_name}.pem"
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

  enable_dns_hostnames = true
}

resource "aws_subnet" "mySubnet1" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  vpc_id     = "${aws_vpc.myVpc.id}"
  cidr_block = "192.168.0.0/24"

  availability_zone_id = "aps1-az1"

  tags = {
    Name = "my-subnet1"
  }

  map_public_ip_on_launch = true
}

resource "aws_subnet" "mySubnet2" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  vpc_id     = "${aws_vpc.myVpc.id}"
  cidr_block = "192.168.1.0/24"

  availability_zone_id = "aps1-az1"

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

resource "aws_eip" "myEip" {
  depends_on = [
    aws_instance.wordpress,
    aws_instance.mysql,
  ]
  vpc      = true
}

resource "aws_nat_gateway" "myNatGateway" {
  depends_on = [
    aws_subnet.mySubnet1,
    aws_eip.myEip,
  ]
  allocation_id = "${aws_eip.myEip.id}"
  subnet_id     = "${aws_subnet.mySubnet1.id}"

  tags = {
    Name = "my-nat-gateway"
  }
}

resource "aws_route_table" "myRouteTableNat" {
  depends_on = [
    aws_vpc.myVpc,
    aws_nat_gateway.myNatGateway,
  ]

  vpc_id = "${aws_vpc.myVpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.myNatGateway.id
  }

  tags = {
    Name = "my-route-table-nat"
  }
}

resource "aws_route_table_association" "associateRouteTableWithPrivateSubnet" {
  depends_on = [
    aws_subnet.mySubnet2,
    aws_route_table.myRouteTableNat,
  ]
  subnet_id      = aws_subnet.mySubnet2.id
  route_table_id = aws_route_table.myRouteTableNat.id
}

resource "aws_security_group" "allowHttp" {
  depends_on = [
    aws_vpc.myVpc,
  ]

  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.myVpc.id}"

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
}

resource "aws_security_group" "allowMysql" {
  depends_on = [
    aws_vpc.myVpc,
  ]
  name        = "allow_mysql"
  description = "Allow mysql inbound traffic"
  vpc_id      = "${aws_vpc.myVpc.id}"

  ingress {
    description = "TCP from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.allowHttp.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allowBashing" {
  depends_on = [
    aws_vpc.myVpc,
  ]
  name        = "allow_bashing"
  description = "Security Group for Bashing Host"
  vpc_id      = "${aws_vpc.myVpc.id}"

  ingress {
    description = "SSH from bashing"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.allowHttp.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "mysql" {
  depends_on = [
    aws_security_group.allowMysql,
  ]
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.allowMysql.id, aws_security_group.allowBashing.id]
  subnet_id = "${aws_subnet.mySubnet2.id}"
  tags = {
      Name = "mysql"
  }
}

resource "aws_instance" "wordpress" {
  depends_on = [
    aws_security_group.allowHttp,
    aws_instance.mysql,
  ]
  ami = "ami-7e257211"
  instance_type = "t2.micro"
  key_name = var.key_name
  vpc_security_group_ids = ["${aws_security_group.allowHttp.id}"]
  subnet_id = "${aws_subnet.mySubnet1.id}"
  tags = {
      Name = "wordpress"
  }
}