# terraform_eks_module
terraform module for [AmazonEKS](https://aws.amazon.com/jp/eks/)

You can easily build an EKS cluster by writing a few lines of config.

# sample

```
module "eks_test" {
  // this modules install location
  source       = "../module_installation_location"
  // your cluster name
  cluster-name = "eks-test"
  // your vpc identifer
  vpc_id       = "${data.aws_vpc.vpc.id}"
  // Subnets Where to place the master
  master-subnet-ids = [
    "${data.aws_subnet.public_1a.id}",
    "${data.aws_subnet.public_1c.id}",
  ]
  // Subnets Where to place the workerNode
  worker-vpc-zone-identifiers = [
    "${data.aws_subnet.private_1a.id}",
    "${data.aws_subnet.private_1c.id}",
  ]
  // security groups you want to grant to the worker node
  cluster-node-sg-ids = [
    "${data.aws_security_group.ssh.id}",
  ]
}

// If you need to Display kubeconfig,when terraform apply
output "kubeconfig" {
  value = "${module.eks_test.kubeconfig}"
}

// If you need to Display aws_auth,when terraform apply
output "aws_out" {
  value = "${module.eks_test.config_map_aws_auth}"
}
```

# Supported variables


| Name | Description |Default|Required|
|------|-------------|-------|--------|
|vpc_id|your vpc_id||True|
|cluster_name|your clustername||True|
|worker-instance-type|worker node instance type|c5.large|False|
|master-subnet-ids|Subnets Where to place the master||True|
|allow-access-master-ips|ip list for allow access masterNode||False|
|eks-optimized-ami-id|please see https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html|ami-063650732b3e8b38c|False|
|region|aws region|ap-northeast-1|False|
|worker-asg-desired|worker instance desired num|2|False|
|worker-asg-max|worker instance max num|2|False|
|worker-asg-min|worker instance min num|2|False|
|worker-vpc-zone-identifiers|Subnets Where to place the workerNode||True|
|cluster-node-sg-ids|security groups you want to grant to the worker node||False|

