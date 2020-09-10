// Configuring the provider information
provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
}

# resource "aws_vpc" "test_vpc" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_hostnames = false
#   enable_dns_support = false
# }

resource "aws_subnet" "sub1" {
  cidr_block = "10.0.3.0/24"
  vpc_id = "vpc-0c5c4991e30772e08"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "sub2" {
  cidr_block = "10.0.2.0/24"
  vpc_id = "vpc-0c5c4991e30772e08"
  availability_zone = "ap-south-1b"
}

resource "aws_db_subnet_group" "dbsubnet" {
  name       = "main"
  subnet_ids = ["${aws_subnet.sub1.id}","${aws_subnet.sub2.id}"]
}

resource "aws_db_instance" "wordpress" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.6"
  instance_class       = "db.t2.micro"
  identifier           = "wordpressmysql"
  name                 = "wordpressmysql"
  username             = "root"
  password             = "ankushroot"
  parameter_group_name = "default.mysql5.6"
  db_subnet_group_name = "${aws_db_subnet_group.dbsubnet.name}"
  final_snapshot_identifier = "demo-wordpressmysql"
  skip_final_snapshot  = true
  apply_immediately    = true
  publicly_accessible = true
  iam_database_authentication_enabled = true
  backup_retention_period  = 0
}

output "ip" {
    value = "${aws_db_instance.wordpress.address}"
}

resource "null_resource" "deploy-wordpress" {
    depends_on = [
        aws_db_instance.wordpress,
    ]
  provisioner "local-exec" {
    command = "kubectl create -k ."
  }
}