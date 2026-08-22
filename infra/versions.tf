terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80" # tightened floor from ~> 5.0 (lint fix)
    }
  }

  # Backend is configured at runtime via -backend-config flags.
  # Do NOT add bucket/key/region here.
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
