variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "opensearch-eks"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for the EKS cluster"
  type        = list(string)
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    min_size     = number
    max_size     = number
    desired_size = number
  }))
}
