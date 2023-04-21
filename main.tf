# create vpc:
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "second_lesson_vpc"
  }
}

# lookup available azs in my region:
data "aws_availability_zones" "azs" {
  state = "available"
}

# create public-1a subnet:
resource "aws_subnet" "public-1a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1a"
  }
}

# create public-1b subnet:
resource "aws_subnet" "public-1b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1b"
  }
}

# create private-1a subnet:
resource "aws_subnet" "private-1a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.128/26"
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-1a"
  }
}

# create private-1b subnet:
resource "aws_subnet" "private-1b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.192/26"
  availability_zone       = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-1b"
  }
}

# create natgw_eip:
resource "aws_eip" "natgw_eip" {
  vpc = true

  tags = {
    Name = "natgw_eip"
  }
}

# create natgw:
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw_eip.id
  subnet_id     = aws_subnet.public-1a.id
  depends_on    = [aws_eip.natgw_eip]

  tags = {
    Name = "natgw"
  }
}

# create igw:
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "second_lesson_igw"
  }
}

# create public rtb:
resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rtb"
  }
}

# create private rtb:
resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "private-rtb"
  }
}

# associate public rtb with public-1a:
resource "aws_route_table_association" "public-1a-rtb-assoc" {
  route_table_id = aws_route_table.public-rtb.id
  subnet_id      = aws_subnet.public-1a.id
}

# associate public rtb with public-1b:
resource "aws_route_table_association" "public-1b-rtb-assoc" {
  route_table_id = aws_route_table.public-rtb.id
  subnet_id      = aws_subnet.public-1b.id
}

# associate private rtb with private-1a:
resource "aws_route_table_association" "private-1a-rtb-assoc" {
  route_table_id = aws_route_table.private-rtb.id
  subnet_id      = aws_subnet.private-1a.id
}

# associate private rtb with private-1b:
resource "aws_route_table_association" "private-1b-rtb-assoc" {
  route_table_id = aws_route_table.private-rtb.id
  subnet_id      = aws_subnet.private-1b.id
}

# public sg for ec2:
resource "aws_security_group" "public-sg" {
  name        = "public-sg"
  description = "allow 22 and 80 for www"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all of them
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public_sg"
  }
}

# lookup my ssh key:
data "aws_key_pair" "my_key" {
  key_name = "tentek"
}

# lookup latest amazon-linux-2 AMIs:
data "aws_ami" "amazon-linux-2_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# launch an EC2 instance:
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.amazon-linux-2_ami.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-1a.id
  key_name               = data.aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.public-sg.id]

  user_data = <<EOT
  #!/bin/bash
  yum update -y
  yum install httpd -y
  echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html 
  systemctl start httpd
  systemctl enable httpd
  EOT

  tags = {
    Name = "public_1a_ec2"
  }
}