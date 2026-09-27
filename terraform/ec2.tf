resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  tags                   = { Name = "app-01", Role = "app" }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_instance" "loadbalancer" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.lb_sg.id]
  tags                   = { Name = "lb-01", Role = "loadbalancer" }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  tags                   = { Name = "monitor-01", Role = "monitoring" }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }
}