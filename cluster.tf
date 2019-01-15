# iam for master

resource "aws_iam_role" "cluster-master" {
  name = "${var.cluster-name}-cluster-master"

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

resource "aws_iam_role_policy_attachment" "cluster-master-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cluster-master.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-master-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.cluster-master.name}"
}

# security group for master
resource "aws_security_group" "cluster-master" {
  name        = "${var.cluster-name}-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.cluster-name}-master-sg"
  }
}

resource "aws_security_group_rule" "cluster-ingress-workstation-https" {
  cidr_blocks       = ["${var.allow-access-master-ips}"]
  description       = "allow from internalIP for communicate masterNoes"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.cluster-master.id}"
  to_port           = 443
  type              = "ingress"
}

# master cluster
resource "aws_eks_cluster" "cluster" {
  name     = "${var.cluster-name}"
  role_arn = "${aws_iam_role.cluster-master.arn}"

  vpc_config {
    security_group_ids = [
      "${aws_security_group.cluster-master.id}",
    ]

    subnet_ids = ["${var.master-subnet-ids}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster-master-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-master-AmazonEKSServicePolicy",
  ]
}

# node iam

resource "aws_iam_role" "cluster-worker-node" {
  name = "${var.cluster-name}-cluster-worker-node"

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

resource "aws_iam_role_policy_attachment" "cluster-worker-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.cluster-worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-worker-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.cluster-worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-worker-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.cluster-worker-node.name}"
}

resource "aws_iam_instance_profile" "cluster-worker-node" {
  name = "${var.cluster-name}-cluster-worker-node"
  role = "${aws_iam_role.cluster-worker-node.name}"
}

# worker sg

resource "aws_security_group" "cluster-worker-node" {
  name        = "${var.cluster-name}-cluster-worker-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "terraform-eks-cluster-worker-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "cluster-worker-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.cluster-worker-node.id}"
  source_security_group_id = "${aws_security_group.cluster-worker-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-worker-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster-worker-node.id}"
  source_security_group_id = "${aws_security_group.cluster-master.id}"
  to_port                  = 65535
  type                     = "ingress"
}

# worker access to master 

resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster-master.id}"
  source_security_group_id = "${aws_security_group.cluster-worker-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

# worker autoscaling

data "aws_region" "current" {}

locals {
  node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
aws configure set region "${var.region}"
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
json=$(aws ec2 describe-instances --instance-ids $instance_id)
private_ip_address=$(echo $json | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
private_ip_address=$(echo $private_ip_address | sed -e 's/\./-/g')
hostnamectl set-hostname $private_ip_address
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "cluster-node-asg-config" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.cluster-worker-node.name}"

  image_id      = "${var.eks-optimized-ami-id}"
  instance_type = "${var.worker-instance-type}"
  key_name      = "eks-access"
  name_prefix   = "${var.cluster-name}-cluster-node"

  security_groups = [
    "${aws_security_group.cluster-worker-node.id}",
    "${var.cluster-node-sg-ids}",
  ]

  user_data_base64 = "${base64encode(local.node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "cluster-node-asg" {
  desired_capacity     = "${var.worker-asg-desired}"
  launch_configuration = "${aws_launch_configuration.cluster-node-asg-config.id}"
  max_size             = "${var.worker-asg-max}"
  min_size             = "${var.worker-asg-min}"
  name                 = "${var.cluster-name}-asg"

  vpc_zone_identifier = ["${var.worker-vpc-zone-identifiers}"]

  tag {
    key                 = "Name"
    value               = "${var.cluster-name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

# Configuring kubectl for EKS

locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

# Required Kubernetes Configuration to Join Worker Nodes

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.cluster-worker-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}
