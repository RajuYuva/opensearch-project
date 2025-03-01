provider "aws" {
  region = var.region
  default_tags {
    tags = {
      CreatedBy      = "Terraform"
      Org            = "selft"
      RepositoryName = "Opensearch"
      TeamName       = "Self"
      Service        = "Opensearch"
      Environment    = title(terraform.workspace)
    }
  }
}
