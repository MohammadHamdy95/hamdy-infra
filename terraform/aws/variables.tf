variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "table_name" {
  description = "DynamoDB table for short links"
  type        = string
  default     = "links"
}
