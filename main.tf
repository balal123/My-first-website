resource "aws_launch_template" "balal-lt" {
  name_prefix   = "balal-website"
  image_id      = "ami-03ededff12e34e59e"
  instance_type = "t2.micro"
  user_data = filebase64("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.balal-ec2-sg.id]
}


resource "aws_autoscaling_group" "balal-asg" {
  availability_zones = ["us-east-1a", "us-east-1b"]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2

  launch_template {
    id      = aws_launch_template.balal-lt.id
    version = "$Latest"
  }
}

resource "aws_lb" "balal-lb" {
  name               = "balal-website-alb"
  internal           = false
  load_balancer_type = "application"                                # In order to create lb we should have tg  for application 123
  security_groups    = [aws_security_group.balal-lb-sg.id]
  subnets            = [for subnet in data.aws_subnets.public.ids : subnet]           

}

resource "aws_lb_target_group" "balal-tg" {
  name     = "balal-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-05640946b09d4ffca"
}

resource "aws_autoscaling_attachment" "balal-asg-attachment" {
  autoscaling_group_name = aws_autoscaling_group.balal-asg.id
  lb_target_group_arn    = aws_lb_target_group.balal-tg.arn
}

resource "aws_lb_listener" "balal-listener" {
  load_balancer_arn = aws_lb.balal-lb.arn
  port              = "80"
  protocol          = "HTTP"                         #listener as a forward sign
  

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.balal-tg.arn
  }
}

resource "aws_security_group" "balal-ec2-sg" {
  name        = "balal-ec2-sg"
  description = "traffic from loadbalancer"
  vpc_id      = "vpc-05640946b09d4ffca"

  ingress {
    description      = "traffic from loadbalancer"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.balal-lb-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "balal-lb-sg" {
  name        = "balal-lb-sg"
  description = "traffic from internet"
  vpc_id      = "vpc-05640946b09d4ffca"

  ingress {
    description      = "traffic from internet"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = ["vpc-05640946b09d4ffca"]
  }
}