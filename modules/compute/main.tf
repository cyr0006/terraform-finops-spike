locals {
  #Graviton (t4g) instances are ARM, so they need an ARM image
  architecture = startswith(var.instance_type, "t4g") ? "arm64" : "x86_64"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-${local.architecture}"]
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true #dont leave a billed volume behind 
  }

  tags = {
    Name = var.instance_name
  }
}
