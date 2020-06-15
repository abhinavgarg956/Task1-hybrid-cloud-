provider  "aws"{ 
                profile ="myabhinav" 
                region="ap-south-1"
} 

#
resource "aws_security_group" "webserver_sg" {
    name        = "openHTTP"
    description = "https, ssh, icmp"
    vpc_id      =  "vpc-9bc4dbf3"
ingress {
        description = "http"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
ingress {
        description = "ping-icmp"
        from_port   = -1
        to_port     = -1
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }
egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
tags = {
        Name = "openSSHnHTTP"
    }
}

#
#
#

resource "tls_private_key" "mykey1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "mykey1"
  public_key = "${tls_private_key.mykey1.public_key_openssh}"

depends_on=[
                            tls_private_key.mykey1
                                   ]  

} 


resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey1"
  security_groups = [ "openHTTP" ]

tags = { 
   Name ="Task 1" 
} 
  }
resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
} 
resource "null_resource" "nullremote3"  {
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey1.private_key_pem}"
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo yum install git -y" ,
      "sudo systemctl restart httpd", 
      "sudo systemctl enable httpd" ,
	 "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/abhinavgarg956/webpage/   /var/www/html/",
    ]
  }
provisioner "local-exec" {
command = "git clone https://github.com/abhinavgarg956/webpage"
}
} 
#
#
#
resource "aws_s3_bucket" "b" {
depends_on = [aws_volume_attachment.ebs_att,]

bucket = "s3abhinavtask"
  acl    = "private"

  tags = {
    Name = "My bucket"
  }
}

resource "aws_s3_bucket_object"  "object" { 
   bucket = "${aws_s3_bucket.b.id}" 
   key = "p.jpg" 
   source = "webpage/p.jpg" 
   acl="public-read"
} 
locals {
  s3_origin_id = "abhinavtask22"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloud front for continous delivery"
  default_root_object = "index.html"

restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

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

 tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullremote4" { 
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey1.private_key_pem}"
    host     = aws_instance.web.public_ip
  }
provisioner "remote-exec"{ 
inline=[ "sudo su <<EOF",
         "echo \"<img src= 'http://${aws_cloudfront_distribution.s3_distribution.domain_name}/p.jpg' height='300'>\"  >> /var/www/html/index.html",
] 
} 
provisioner "local-exec" {
command = "start chrome ${aws_instance.web.public_ip}"
}
}
 
