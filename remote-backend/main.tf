provider "aws" {
  version    = "~> 2.2"
  region     = "us-west-2"
}

resource "aws_s3_bucket" "tf-state-storage" {
  # Must be globally unique.
  bucket = "rdtfstate2"

  # This allows you to roll back in the case of errors.
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
  
  attribute {
    name = "LockID"
    type = "S"
  }
}