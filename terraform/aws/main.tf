terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state backend to be configured (see workspace HLD).
}

# Credentials via AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "hamdy-app"
      managed-by = "terraform"
    }
  }
}

# Short links. slug -> url plus click stats; a redirect is one GetItem.
resource "aws_dynamodb_table" "links" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # ≈ $0 at hobby traffic
  hash_key     = "slug"

  attribute {
    name = "slug"
    type = "S"
  }

  # Expired links are enforced at read time by the backend; TTL cleans
  # up the rows afterwards (epoch seconds).
  ttl {
    attribute_name = "expires_at_epoch"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }
}

# Identity the backend container runs as. Long-lived keys are the
# pragmatic choice for a service living outside AWS (no role to assume
# from a home server); blast radius is capped by the policy below.
resource "aws_iam_user" "shortener_backend" {
  name = "shortener-backend"
}

resource "aws_iam_user_policy" "links_rw" {
  name = "links-table-rw"
  user = aws_iam_user.shortener_backend.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LinksTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]
        Resource = aws_dynamodb_table.links.arn
      },
    ]
  })
}

# Access key for the backend. The secret lands in Terraform state —
# acceptable for a single-operator project with private state; rotate
# by tainting this resource.
resource "aws_iam_access_key" "shortener_backend" {
  user = aws_iam_user.shortener_backend.name
}
