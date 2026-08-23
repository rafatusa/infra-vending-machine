# Data sources for new-app

data "aws_vpc" "target" {
  filter {
    name   = "tag:Name"
    values = ["new-app"]
  }
}
data "aws_subnet" "target" {
  filter {
    name   = "tag:Name"
    values = ["new-app"]
  }
  vpc_id = data.aws_vpc.target.id
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
