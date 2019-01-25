resource "aws_security_group" "eks_cluster" {
  name        = "eks-${local.cluster_name}-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${module.eks_vpc.vpc_id}"

  tags {
    Name        = "eks-${local.cluster_name}-cluster"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group_rule" "eks_ingress_admin_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  cidr_blocks       = ["${local.admin_ip}/32"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.eks_cluster.id}"
}

resource "aws_security_group_rule" "eks_cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_cluster.id}"
  source_security_group_id = "${aws_security_group.eks_worker.id}"
  to_port                  = 443
}

resource "aws_security_group_rule" "eks_cluster_egress" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.eks_cluster.id}"
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-${local.cluster_name}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_eks_cluster" "cluster" {
  name     = "${local.cluster_name}"
  role_arn = "${aws_iam_role.eks_cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks_cluster.id}"]
    subnet_ids         = ["${module.eks_vpc.private_subnets}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks_cluster_policy",
    "aws_iam_role_policy_attachment.eks_service_policy",
  ]
}
