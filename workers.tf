resource "aws_iam_role" "eks_worker" {
  name = "eks-${local.cluster_name}-worker"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks_worker.name}"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.eks_worker.name}"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks_worker.name}"
}

resource "aws_iam_instance_profile" "eks_worker" {
  name = "eks-${local.cluster_name}-worker"
  role = "${aws_iam_role.eks_worker.name}"
}

resource "aws_security_group" "eks_worker" {
  name        = "eks-${local.cluster_name}-worker"
  description = "Security group for all worker nodes in the cluster"
  vpc_id      = "${module.eks_vpc.vpc_id}"

  tags {
    Name                                          = "eks-${local.cluster_name}-worker"
    Environment                                   = "${var.environment}"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "eks_worker_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.eks_worker.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_worker_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.eks_cluster.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_worker_ingress_ssh" {
  description              = "Allow worker ssh from bastions"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks_worker.id}"
  source_security_group_id = "${aws_security_group.bastion.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_worker_egress_admin_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.eks_worker.id}"
}

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks_worker_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh \
  --apiserver-endpoint '${aws_eks_cluster.cluster.endpoint}' \
  --b64-cluster-ca '${aws_eks_cluster.cluster.certificate_authority.0.data}' \
  '${local.cluster_name}'
USERDATA
}

resource "aws_launch_configuration" "eks_worker" {
  associate_public_ip_address = false
  iam_instance_profile        = "${aws_iam_instance_profile.eks_worker.name}"
  image_id                    = "${data.aws_ami.eks_worker.id}"
  instance_type               = "${lookup(var.instance_types, "worker")}"
  name_prefix                 = "eks-${local.cluster_name}-worker"
  security_groups             = ["${aws_security_group.eks_worker.id}"]
  user_data_base64            = "${base64encode(local.eks_worker_userdata)}"
  key_name                    = "${aws_key_pair.ssh.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks_worker" {
  launch_configuration = "${aws_launch_configuration.eks_worker.id}"
  desired_capacity     = "${var.eks_worker_count}"
  max_size             = "${var.eks_worker_count}"
  min_size             = 1
  name                 = "eks-${local.cluster_name}-worker"
  vpc_zone_identifier  = ["${module.eks_vpc.private_subnets}"]

  tag {
    key                 = "Name"
    value               = "eks-${local.cluster_name}-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${local.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
