# Terraform_ALB_AWS
Deploying a web server and a application load balancer with Terraform on AWS

![Terraform](https://github.com/diiegg/Terraform_ALB_AWS/workflows/Terraform/badge.svg)
![Markdown](https://github.com/diiegg/Terraform_ALB_AWS/workflows/Markdown/badge.svg)
[![GitHub tag](https://img.shields.io/github/tag/tmknom/terraform-aws-alb.svg)](https://registry.terraform.io/modules/tmknom/alb/aws)
[![License](https://img.shields.io/github/license/tmknom/terraform-aws-alb.svg)](https://opensource.org/licenses/MIT)

# AWS Front-End Terraform module

**Topics**

Terraform module which sets up an application load balancer and a web server.

The following resources are created:

 - Application load balancer (internal or external) 
 - Load balancer listener(s) (HTTP, HTTPS) 
 - Target group(s) (HTTP, HTTPS)
 - Security groups 
 - Nginx server
 -  Elastic IP address
 - DNS entry

   
## Requisites
 
- [AWS Account](https://aws.amazon.com)

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- An existing VPC
- Some existing subnets
- AWS secret and public keys

 ## Requirements

| Name | Version |
|--|--|
|  terraform| >= 0.12  |

## Providers

|Name| Version
|--|--|
| AWS | N/A |
  
### Terraform Version

Terraform 0.12. Pin module version to ⇾ v2.0. Submit pull-requests to master branch.

### Description

This module provides:

- [Elastic IP Address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
- [Application load balancer (ALB)](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [Ec2 instance](https://aws.amazon.com/ec2/instance-types/)
- [NginX web server)](https://www.nginx.com)

## Usage

  ```sh
git clone https://github.com/diiegg/Terraform_ALB_AWS.git

cd Terraform_ALB_AWS

terraform init

terrafom plan

terraform apply
```
## Module
  ```sh
  #ec2 instances
resource "aws_instance" "base" {
  count                  = 2
  ami                    = "ami-2757f631"
  instance_type          = "t2.micro"
  key_name               = "aws.red"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  # subnet_id              = "subnet-8f1abdae"
  user_data = <<-EOF
          #! /bin/bash
          sudo apt-get -y update
          sudo apt-get -y install nginx
          sudo service nginx start
          echo "<h1> hey Im server $(hostname -f) nice to meet you</h1>" >> /var/www/html/index.html
  EOF        

  tags = {

    Name = "frontEmd-${count.index}"

  }

}
#elastic ip 
resource "aws_eip" "myeip" {
  count    = length(aws_instance.base)
  vpc      = true
  instance = "${element(aws_instance.base.*.id, count.index)}"

  tags = {
    Name = "LABinstance-${count.index + 1}"
  }
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
#security group
resource "aws_security_group" "allow_ports" {
  name        = "alb"
  description = "Allow inbound traffic"
  vpc_id      = "${aws_default_vpc.default.id}"
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NGINX port VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLC port VPC"
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
    Name = "allow_ports"
  }

}
#adding existing subnets
data "aws_subnet_ids" "subnet" {

  vpc_id = "${aws_default_vpc.default.id}"

}
#healt check
resource "aws_alb_target_group" "my-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "terraform-example-alb-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_default_vpc.default.id}"
  target_type = "instance"
}

#create a new load balancer
resource "aws_alb" "front_end" {
  name               = "frontEnd-alb"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "ipv4"
  security_groups    = ["${aws_security_group.allow_ports.id}"]
  subnets            = data.aws_subnet_ids.subnet.ids

  tags = {
    Name = "web-terraform-alb"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_alb.front_end.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.my-target-group.arn}"

  }
}
#attach ec2 instances
resource "aws_alb_target_group_attachment" "ec2_attach" {
  count            = length(aws_instance.base)
  target_group_arn = aws_alb_target_group.my-target-group.arn
  target_id        = aws_instance.base[count.index].id
}

``` 
# Demo

[Try me](http://frontend-alb-2111721551.us-east-1.elb.amazonaws.com)

License.
----
MIT

# References.

  

- [Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

- [AWS  Load balancing](https://aws.amazon.com/elasticloadbalancing/getting-started/)
