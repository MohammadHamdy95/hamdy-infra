variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "table_name" {
  description = "DynamoDB table for short links"
  type        = string
  default     = "links"
}
