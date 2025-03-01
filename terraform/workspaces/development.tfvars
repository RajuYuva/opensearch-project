region = "us-east-1"
eks_cluster_name = "opensearch-eks-dev"
vpc_id = "vpc-0dec0acbaee82b9eb"
private_subnets = ["subnet-035e0b614379b0ec9", "subnet-020668249d1d4eba9"]
node_groups = {
  opensearch_nodes = {
    min_size     = 2
    max_size     = 3
    desired_size = 2
  }
}
