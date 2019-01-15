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

| Name | Description |Required|
|------|-------------|True/False|
|vpc_id|your vpc_id|True|
|cluster_name|your clustername|True|
|worker-instance-type|default:c5.large|False|
|master-subnet-ids||True|
|allow-access-master-ips|ip list for allow access masterNode|True|
|eks-optimized-ami-id|default ami is ap-north-east1`s|False|
|region|default:ap-northeast-1|False|
|worker-asg-desired|default:2|False|
|worker-asg-max|default:2|False|
|worker-asg-min|default:2|False|
|worker-vpc-zone-identifiers||True|
|cluster-node-sg-ids||True|
