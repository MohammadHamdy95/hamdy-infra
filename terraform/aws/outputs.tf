output "links_table_name" {
  value = aws_dynamodb_table.links.name
}

output "links_table_arn" {
  value = aws_dynamodb_table.links.arn
}

output "shortener_access_key_id" {
  description = "AWS_ACCESS_KEY_ID for the shortener backend (compose/.env)"
  value       = aws_iam_access_key.shortener_backend.id
}

output "shortener_secret_access_key" {
  description = "AWS_SECRET_ACCESS_KEY for the shortener backend (compose/.env)"
  value       = aws_iam_access_key.shortener_backend.secret
  sensitive   = true
}
