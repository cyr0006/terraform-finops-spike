module "storage" {
  source        = "./modules/storage"
  bucket_prefix = "finops-spike-"
}

module "compute" {
  source        = "./modules/compute"
  instance_name = var.instance_name
  instance_type = var.instance_type

}
