resource "aws_s3_bucket" "this" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true #Lets destroy delete a bucked containing objects; good for this spike but not good for production
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" #free, S3 managed encryption
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cost control"
    status = "Enabled"

    filter {} #apply to every object through empty filter

    #move objects to the cheaper infrequent access storage class after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    #old versions would be kept indefinately unless we tell S3 to delete them after a certain number of days
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiry_days
    }

    #failed partial uploads cane are brilled but invisible in the console, so we should clean them up after a few days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
