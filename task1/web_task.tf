// Configuring the provider information
provider "aws" {
    region = "ap-south-1"
    profile = "ankush"
}

// Creating the EC2 private key
variable "key_name" {
  default = "Terraform_test"
}

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
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
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
    key_name = var.key_name
    vpc_security_group_ids = ["${aws_security_group.allow_tcp.id}"]
    subnet_id = "subnet-2f0b3147"
    tags = {
        Name = "TeraTaskOne"
    }
    user_data = "${file("vol.sh")}"
}

// Creating EBS volume
resource "aws_ebs_volume" "myWebVol" {
  availability_zone = "${aws_instance.myWebOS.availability_zone}"
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

// Creating private S3 Bucket
resource "aws_s3_bucket" "tera_bucket" {
  bucket = "terra-bucket-test"
  acl    = "private"

  tags = {
    Name        = "terra_bucket"
  }
}

// Block Public Access
resource "aws_s3_bucket_public_access_block" "s3BlockPublicAccess" {
  bucket = "${aws_s3_bucket.tera_bucket.id}"

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
}

//
locals {
  s3_origin_id = "myS3Origin"
}

// Creating Origin Access Identity for CloudFront
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Tera Access Identity"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.tera_bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      # origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Terra Access Identity"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["CA"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  retain_on_delete = true
}

// AWS Bucket Policy for CloudFront
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tera_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.tera_bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "s3BucketPolicy" {
  bucket = "${aws_s3_bucket.tera_bucket.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
}

//
# module "gitModule" {
#   source = "github.com/cankush625/Web/assets"
# }

# output "gitModuleSource" {
#   value = module.gitModule.source
# }

//
# resource "aws_s3_bucket_object" "object" {
#   bucket = "${aws_s3_bucket.tera_bucket.bucket}"
#   key    = "/assets/"
#   source = "/home/cankush/Downloads/assets"
# }

resource "aws_s3_bucket_object" "bucketObject" {
  for_each = fileset("/home/cankush/Downloads/assets", "**/*.jpg")

  bucket = "${aws_s3_bucket.tera_bucket.bucket}"
  key    = each.value
  source = "/home/cankush/Downloads/assets/${each.value}"
  content_type = "image/jpg"
}