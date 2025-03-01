output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "opensearch_endpoint" {
  description = "OpenSearch Cluster Endpoint"
  value       = "https://${module.eks.cluster_name}.opensearch.local"
}
