variable "vpc_id" {
  description = "VPC ID"
  default = "vpc-c5e13fa2"
}

provider "aws" {
  region = "us-west-2"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

	#### Creates Single Internet Gateway ####
resource "aws_internet_gateway" "gw" {
  vpc_id = "${var.vpc_id}"

  tags = {
    Name = "default_ig"
  }
}

	##### Create NAT gateway #####
resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.lb.id}"
  subnet_id = "${aws_subnet.private_subnet_a.id}"
 } 
resource "aws_eip" "lb" {
  depends_on = ["aws_internet_gateway.gw"]
  vpc = true
}

	##### Creates Public Routing Table #####
resource "aws_route_table" "public_routing_table" {
    vpc_id ="${var.vpc_id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    tags {
        Name = "public_routing_table"
    }
}

	#### Creates Private Routing Table ####
resource "aws_route_table" "private_routing_table" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }
  tags {
    Name = "private_routing_table"
  }
}


	#### Creates 3 Public Subnets ####
		## A
	resource "aws_subnet" "public_subnet_a" {
    vpc_id = "${var.vpc_id}"
    #giving it 256 addresses
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-west-2a"

    tags {
        Name = "public_a"
    }
}

		## B
resource "aws_subnet" "public_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-west-2b"

    tags {
        Name = "public_b"
    }
}

		## C
resource "aws_subnet" "public_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-west-2c"

    tags {
        Name = "public_c"
    }
}

	#### Creates 3 Private Subnets #####

		## A
resource "aws_subnet" "private_subnet_a" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "10.0.16.0/22"
    availability_zone = "us-west-2a"

    tags {
        Name = "private_a"
    }
}

		## B
resource "aws_subnet" "private_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "10.0.20.0/22"
    availability_zone = "us-west-2b"

    tags {
        Name = "private_b"
    }
}

		## C
resource "aws_subnet" "private_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "10.0.24.0/22"
    availability_zone = "us-west-2c"

    tags {
        Name = "private_c"
    }
}

#### Route Table Association ####

	## A
resource "aws_route_table_association" "public_subnet_a_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

	## B
resource "aws_route_table_association" "public_subnet_b_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_b.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

	## C
resource "aws_route_table_association" "public_subnet_c_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_c.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}



	#### Bastion Instance ####
resource "aws_instance" "bastion" {
    ami = "ami-5ec1673e"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    instance_type = "t2.micro"
    key_name = "${var.aws_key_name}"
    security_groups = ["${aws_security_group.bastion.id}"]
    tags {
        Name = "Bastion"
    }
}

	#### Security Group [Bastion] ####
resource "aws_security_group" "bastion" {
	name = "bastion"
	description = "Allow access from your current public IP address to an instance on port 22 (SSH)"
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["172.32.0.0/16"]
	}

	vpc_id = "${var.vpc_id}"
}
	#### Security Group for DB ####
resource "aws_security_group" "DB" {
	name = "DB"
	description = "Security Group for DB"
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/16"]
	}

	vpc_id = "${var.vpc_id}"
}

	#### DB Subnet Group ####
resource "aws_db_subnet_group" "default" {
    name = "db_subnet_group"
    subnet_ids = ["${aws_subnet.private_subnet_a.id}", "${aws_subnet.private_subnet_b.id}"]
    tags {
        Name = "DB Subnet Group"
    }
}

	#### RDS Instance [Relations Database Service] ####
resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 5
  engine               = "mariadb"
  engine_version       = "10.0.24"
  instance_class       = "db.t2.micro"
  multi_az			   = "false"
  publicly_accessible  = "false"
  storage_type		   = "gp2"
  name                 = "maria_db"
  username             = "admin"
  password             = "password"
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"

  tags {
  		Name = "RDS Instance"
	}
}


	#### Security Groups ####
resource "aws_security_group" "web" {
	name = "securityweb"
	description = "Security Group for Web Instances"
	ingress {
		from_port = 80
		to_port = 80
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/16"]
	}

	vpc_id = "${var.vpc_id}"
}

resource "aws_security_group" "elb_security" {
	name = "securityelb"
	description = "Security group for the ELB"
	ingress {
		from_port = 80
		to_port = 80
		protocol = "0"
		cidr_blocks = ["0.0.0.0/0"]
	}

	vpc_id = "${var.vpc_id}"
}

	#### Elastic Load Balancer ####
resource "aws_elb" "elb" {
  name = "terraform-elb"
  subnets = ["${aws_subnet.public_subnet_b.id}", "${aws_subnet.public_subnet_c.id}"]
  security_groups = ["${aws_security_group.elb_security.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 5
    target = "HTTP:80/"
    interval = 30
  }

  instances = ["${aws_instance.centos7.id}", "${aws_instance.centos7_2.id}"]
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 60

  tags {
    Name = "terraform_ELB"
  }
}

	#### 2 Instance ####
resource "aws_instance" "centos7" {
    ami = "ami-d2c924b2"
    associate_public_ip_address = false
    subnet_id = "${aws_subnet.private_subnet_b.id}"
    instance_type = "t2.micro"
    key_name = "${var.aws_key_name}"
    security_groups = ["${aws_security_group.web.id}"]
    tags {
        Name = "webserver-b"
        service = "curriculum"
    }
}

resource "aws_instance" "centos7_2" {
    ami = "ami-d2c924b2"
    associate_public_ip_address = false
    subnet_id = "${aws_subnet.private_subnet_c.id}"
    instance_type = "t2.micro"
    key_name = "${var.aws_key_name}"
    security_groups = ["${aws_security_group.web.id}"]
    tags {
        Name = "webserver-c"
        service = "curriculum"
    }
}
