// Configuring provider
provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
} 

// Launching new instance
resource "aws_instance" "myWebOS" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "cankush625"
    vpc_security_group_ids = ["sg-0d596e3fa760e165e"]
    subnet_id = "subnet-2f0b3147"
    tags = {
        Name = "TerraTest"
    }
}