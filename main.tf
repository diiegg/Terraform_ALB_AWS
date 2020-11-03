resource "aws_instance" "ec2" {

  count                  = 2
  ami                    = "ami-2757f631"
  instance_type          = "t2.micro"
  key_name               = "aws.red"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.frontend_ports.id]
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

resource "aws_eip" "myeip" {
  count    = length(aws_instance.ec2)
  vpc      = true
  instance = "${element(aws_instance.ec2.*.id, count.index)}"

  tags = {
    Name = "LABinstance-${count.index + 1}"
  }
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "frontend_ports" {
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
    Name = "frontend_ports"
  }

}

data "aws_subnet_ids" "subnet" {

  vpc_id = "${aws_default_vpc.default.id}"

}

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

# Create a new load balancer
resource "aws_alb" "front_end" {
  name               = "frontEnd-alb"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "ipv4"
  security_groups    = ["${aws_security_group.frontend.id}"]
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
resource "aws_alb_target_group_attachment" "ec2_attach" {
  count            = length(aws_instance.ec2)
  target_group_arn = aws_alb_target_group.my-target-group.arn
  target_id        = aws_instance.ec2[count.index].id
}
