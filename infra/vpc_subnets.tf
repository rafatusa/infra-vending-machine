# ---------------------------------------------------------------------------
# EKS Subnets — 2 public subnets in separate AZs
#
# EKS managed control plane requires subnets in at least 2 availability zones.
# CIDRs are carved from the VPC's /16 block at offsets 10 and 11 (/24 each):
#
#   Subnet 1: cidrsubnet(vpc_cidr, 8, 10) → e.g. 10.0.10.0/24 in us-east-1a
#   Subnet 2: cidrsubnet(vpc_cidr, 8, 11) → e.g. 10.0.11.0/24 in us-east-1b
#
# These offsets avoid the first 10 /24 blocks which the existing subnet likely
# occupies. Adjust if your VPC already uses 10.x ranges.
#
# Tags:
#   kubernetes.io/role/elb=1            — allows future ALB Ingress Controller
#   kubernetes.io/cluster/<name>=shared — EKS control plane subnet discovery
#
# Guarded by count = var.create_eks ? 2 : 0 — no-op when toggle is false.
# ---------------------------------------------------------------------------

resource "aws_subnet" "eks" {
  count             = var.create_eks ? 2 : 0
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 10 + count.index)
  availability_zone = "${var.region}${element(["a", "b"], count.index)}"

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                                = "${var.project_name}-eks-subnet-${count.index + 1}"
    "kubernetes.io/role/elb"                            = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"     = "shared"
  })
}
