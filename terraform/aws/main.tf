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
  region = "eu-central-1"
}

# Planned resources (see HLD §2.2):
# - aws_dynamodb_table.links        — PK "slug", on-demand billing, PITR on
# - aws_iam_user.shortener_backend  — least-privilege, links table only
# - aws_iam_user_policy.links_rw
