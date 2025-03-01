# Create EKS Cluster
# ckv:skip=CKV_TF_1: Using official module without commit hash
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.27"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["m5.large"]
  }

  # Auto-Scaling for OpenSearch
  eks_managed_node_groups = {
    for name, config in var.node_groups : name => {
      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size
    }
  }
}
