# IAM Role for OpenSearch Operator

resource "aws_iam_role" "opensearch_irsa" {
  name               = "opensearch-irsa"
  assume_role_policy = data.aws_iam_policy_document.opensearch_irsa_assume_role.json
}

resource "aws_iam_policy" "opensearch_policy" {
  name        = "opensearch-policy"
  description = "Policy for OpenSearch access"
  policy      = data.aws_iam_policy_document.opensearch_policy_document.json
}

resource "aws_iam_role_policy_attachment" "opensearch_attach" {
  role       = aws_iam_role.opensearch_irsa.name
  policy_arn = aws_iam_policy.opensearch_policy.arn
}
