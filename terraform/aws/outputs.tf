output "links_table_name" {
  value = aws_dynamodb_table.links.name
}

output "links_table_arn" {
  value = aws_dynamodb_table.links.arn
}

output "shortener_access_key_id" {
  description = "SHORTENER_AWS_ACCESS_KEY_ID for compose/.env — narrow IAM user, not your deployer credentials"
  value       = aws_iam_access_key.shortener_backend.id
}

output "shortener_secret_access_key" {
  description = "SHORTENER_AWS_SECRET_ACCESS_KEY for compose/.env — narrow IAM user, not your deployer credentials"
  value       = aws_iam_access_key.shortener_backend.secret
  sensitive   = true
}
