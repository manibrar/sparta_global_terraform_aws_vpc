provider "aws" {
  region = "eu-west-1"
}

resource "aws_route53_record" "manvir" {
  zone_id = "Z3CCIZELFLJ3SC"
  name    = "manvir.spartaglobal.education"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_elb.elb_manvir.dns_name}"]
}

resource "aws_route_table" "manvir_route_table" {
  vpc_id = "${aws_vpc.manvir_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "manvir-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.elb_subnet.id}"
  route_table_id = "${aws_route_table.manvir_route_table.id}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.manvir_vpc.id}"
  tags {
    Name = "main"
  }
}

resource "aws_security_group" "elb_sg_manvir" {
  name        = "elb-sg-manvir"
  description = "security group for elb"
  vpc_id      = "${aws_vpc.manvir_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_vpc" "manvir_vpc" {
  cidr_block       = "10.5.0.0/16"
  tags {
    Name = "manvir-vpc"
  }
}

data "template_file" "app_user_data" {
  template = "${file("${path.module}/templates/app/user_data.sh.tpl")}"
  vars {
    db_host = "mongodb://${aws_instance.db_instance.private_ip}:27017/posts"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id     = "${aws_vpc.manvir_vpc.id}"
  cidr_block = "10.5.0.0/24"
  availability_zone = "eu-west-1a"
  tags {
    Name = "subnet-app-manvir"
  }
}

resource "aws_security_group" "app_sg_manvir" {
  name        = "app-sg-manvir"
  description = "security group for app"
  vpc_id      = "${aws_vpc.manvir_vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.elb_sg_manvir.id}"]
    cidr_blocks = ["10.5.1.0/24"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.5.1.0/24"]
  }
}

resource "aws_instance" "app-instance" {
  ami = "ami-c2b8bfbb"
  instance_type = "t2.micro"
  user_data = "${data.template_file.app_user_data.rendered}"
  subnet_id = "${aws_subnet.app_subnet.id}"
  security_groups = ["${aws_security_group.app_sg_manvir.id}"]
  tags {
    Name = "Manvir-app"
  }
}

resource "aws_subnet" "db_subnet" {
  vpc_id     = "${aws_vpc.manvir_vpc.id}"
  cidr_block = "10.5.1.0/24"
  availability_zone = "eu-west-1a"
  tags {
    Name = "subnet-db-manvir"
  }
}

resource "aws_security_group" "db_sg_manvir" {
  name        = "db-sg-manvir"
  description = "security group for db"
  vpc_id      = "${aws_vpc.manvir_vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.app_sg_manvir.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.5.0.0/24"]
  }
}

resource "aws_instance" "db_instance" {
  ami = "ami-01020378"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.db_subnet.id}"
  security_groups = ["${aws_security_group.db_sg_manvir.id}"]
  tags {
    Name = "Manvir-db"
  }
}

resource "aws_subnet" "elb_subnet" {
  vpc_id     = "${aws_vpc.manvir_vpc.id}"
  cidr_block = "10.5.2.0/24"
  availability_zone = "eu-west-1a"

  tags {
    Name = "subnet-elb-manvir"
  }
}

resource "aws_elb" "elb_manvir" {
  name               = "elb-manvir"
  subnets = ["${aws_subnet.elb_subnet.id}"]
  security_groups = ["${aws_security_group.elb_sg_manvir.id}"]
  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = ["${aws_instance.app-instance.id}"]

  tags {
    Name = "elb-manvir"
  }
}
