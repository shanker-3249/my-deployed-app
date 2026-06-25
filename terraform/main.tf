# ─────────────────────────────────────────────
#  Provider
# ─────────────────────────────────────────────
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
#  Data Sources
# ─────────────────────────────────────────────
# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# ─────────────────────────────────────────────
#  Security Group  (HTTP + SSH)
# ─────────────────────────────────────────────
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-sg"
  }
}

# ─────────────────────────────────────────────
#  IAM Role for EC2
# ─────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.app_name}-ec2-role"
  }
}

# Attach SSM policy so you can connect without SSH key if needed
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach read-only S3 policy (example of scoped IAM)
resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ─────────────────────────────────────────────
#  EC2 Instance  (t3.small)
# ─────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Bootstrap script – runs once at first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # System update
    dnf update -y

    # Install Node.js 20
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs git

    # Install PM2 (process manager keeps app alive)
    npm install -g pm2

    # Install nginx as reverse proxy
    dnf install -y nginx
    cat > /etc/nginx/conf.d/app.conf <<'NGINX'
    server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    NGINX

    systemctl enable nginx
    systemctl start nginx

    # Create app directory
    mkdir -p /home/ec2-user/app
    chown ec2-user:ec2-user /home/ec2-user/app

    # Clone and start the app
    cd /home/ec2-user/app
    git clone ${var.github_repo} . || true
    cd app
    npm install --production
    pm2 start server.js --name my-app
    pm2 startup systemd -u ec2-user --hp /home/ec2-user
    pm2 save

    echo "Bootstrap complete" >> /var/log/bootstrap.log
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = {
    Name        = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────
#  Elastic IP (so the IP doesn't change)
# ─────────────────────────────────────────────
resource "aws_eip" "app_eip" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.app_name}-eip"
  }
}
