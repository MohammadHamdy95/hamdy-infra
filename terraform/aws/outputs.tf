output "links_table_name" {
  value = aws_dynamodb_table.links.name
}

output "links_table_arn" {
  value = aws_dynamodb_table.links.arn
}

output "tiny_access_key_id" {
  description = "TINY_AWS_ACCESS_KEY_ID for compose/.env — narrow IAM user, not your deployer credentials"
  value       = aws_iam_access_key.tiny_backend.id
}

output "tiny_secret_access_key" {
  description = "TINY_AWS_SECRET_ACCESS_KEY for compose/.env — narrow IAM user, not your deployer credentials"
  value       = aws_iam_access_key.tiny_backend.secret
  sensitive   = true
}
