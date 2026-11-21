output "bucket_name" {
  description = "The name of the S3 bucket."
  value       = module.storage.bucket_name
}

output "instance_id" {
  description = "Instance id of EC2"
  value       = module.compute.instance_id

}
