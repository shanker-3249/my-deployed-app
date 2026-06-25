# 🚀 AWS EC2 Node.js Deployment – Complete Beginner Guide

A simple Node.js application deployed on AWS EC2 (t3.small) using Terraform for infrastructure,
GitHub Actions for CI/CD, and Nginx as a reverse proxy.

---

## 📐 Architecture Diagram

```
👤 User
  │  HTTP :80
  ▼
┌──────────────────────────────────────────────────┐
│              AWS Cloud  (us-east-1)              │
│                                                  │
│  ┌─────────────┐    ┌─────────────────────────┐ │
│  │  IAM Role   │    │   Security Group        │ │
│  │  SSM + S3   │    │  Port 80 / 3000 / 22    │ │
│  └──────┬──────┘    └──────────┬──────────────┘ │
│         │                      │                 │
│         ▼                      ▼                 │
│  ┌────────────────────────────────────────────┐  │
│  │         EC2 Instance  (t3.small)           │  │
│  │   Elastic IP: YOUR_IP                      │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │  NGINX  (Port 80) – Reverse Proxy    │  │  │
│  │  └────────────────┬─────────────────────┘  │  │
│  │                   │ proxy_pass              │  │
│  │  ┌────────────────▼─────────────────────┐  │  │
│  │  │  Node.js App  (Port 3000)  via PM2   │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘

Developer → git push → GitHub → GitHub Actions → SSH → EC2 (git pull + pm2 reload)
```

---

## 📁 Project Structure

```
deploy-project/
├── app/
│   ├── server.js          ← Node.js application
│   └── package.json
├── terraform/
│   ├── main.tf            ← EC2, SG, IAM, EIP
│   ├── variables.tf       ← All input variables
│   ├── outputs.tf         ← Public IP, SSH command
│   └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       └── deploy.yml     ← GitHub Actions CI/CD
├── architecture.svg
└── README.md
```

---

## ⚙️ Prerequisites – Install These First

### 1. AWS CLI
```bash
# Mac
brew install awscli

# Windows – download from:
# https://awscli.amazonaws.com/AWSCLIV2.msi

# Linux (Ubuntu/Debian)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

### 2. Terraform
```bash
# Mac
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Windows – download from:
# https://developer.hashicorp.com/terraform/downloads

# Linux (Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify
terraform --version
```

### 3. Git
```bash
# Mac
brew install git

# Windows – download from https://git-scm.com

# Linux
sudo apt install git    # Ubuntu/Debian
sudo dnf install git    # Fedora/RHEL

# Verify
git --version
```

---

## 🔑 Step 1 – AWS Setup

### 1a. Create AWS Account
Go to https://aws.amazon.com → Create Account (free tier available).

### 1b. Create IAM User for Terraform (do NOT use root account)
1. Log into AWS Console → Search "IAM" → Click **Users** → **Add users**
2. Username: `terraform-user`
3. Click **Next** → **Attach policies directly** → check `AdministratorAccess`
   *(For production, scope this down. For learning, Admin is easiest.)*
4. Click **Create user**
5. Click on the user → **Security credentials** tab → **Create access key**
6. Choose **CLI** → **Next** → **Create access key**
7. **SAVE the Access Key ID and Secret Access Key** – you only see them once!

### 1c. Configure AWS CLI
```bash
aws configure
# AWS Access Key ID [None]:     PASTE_YOUR_ACCESS_KEY
# AWS Secret Access Key [None]: PASTE_YOUR_SECRET_KEY
# Default region name [None]:   us-east-1
# Default output format [None]: json

# Verify it works
aws sts get-caller-identity
```

### 1d. Create an EC2 Key Pair (for SSH)
```bash
# Create key pair and save the .pem file
aws ec2 create-key-pair \
  --key-name my-key-pair \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-key-pair.pem

# Set correct permissions (REQUIRED on Mac/Linux)
chmod 400 ~/.ssh/my-key-pair.pem

# On Windows, use Git Bash and run the same command
```

---

## 📂 Step 2 – GitHub Repository Setup

### 2a. Create a new repo on GitHub
1. Go to https://github.com → **New repository**
2. Name: `my-deployed-app`
3. Keep it Public or Private (both work)
4. Do NOT initialize with README (we'll push our own)
5. Click **Create repository**

### 2b. Push this project to GitHub
```bash
# In the project root folder
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/my-deployed-app.git
git push -u origin main
```

### 2c. Add GitHub Secrets (for CI/CD)
In your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these two secrets:

| Secret Name  | Value |
|-------------|-------|
| `EC2_HOST`  | Your Elastic IP (you'll get this after Terraform runs) |
| `EC2_SSH_KEY` | The **entire contents** of your `.pem` file |

To get the .pem contents:
```bash
cat ~/.ssh/my-key-pair.pem
# Copy everything including -----BEGIN RSA PRIVATE KEY----- lines
```

---

## 🏗️ Step 3 – Deploy Infrastructure with Terraform

### 3a. Configure your variables
```bash
cd terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit it with your values
nano terraform.tfvars   # or use any text editor
```

Fill in:
```hcl
aws_region    = "us-east-1"
app_name      = "my-node-app"
instance_type = "t3.small"
key_pair_name = "my-key-pair"    # ← name WITHOUT .pem extension
github_repo   = "https://github.com/YOUR_USERNAME/my-deployed-app.git"
environment   = "dev"
```

### 3b. Run Terraform
```bash
# Still inside the terraform/ folder

# Download AWS provider
terraform init

# Preview what will be created (read this carefully!)
terraform plan

# Create everything on AWS
terraform apply
# Type: yes  (when prompted)
```

Terraform will create:
- Security Group (ports 80, 22, 3000)
- IAM Role + Instance Profile
- EC2 t3.small instance
- Elastic IP

**At the end you'll see output like:**
```
app_url     = "http://X.XX.XXX.XXX"
public_ip   = "XX.XX.XXX.XXX"
ssh_command = "ssh -i ~/.ssh/my-key-pair.pem ec2-user@X.XX.XXX.XXX"
```

**Save the `public_ip`!** You need it for the GitHub secret `EC2_HOST`.

### 3c. Update GitHub Secret
Now go back to GitHub → Settings → Secrets → update `EC2_HOST` with your Elastic IP.

---

## ✅ Step 4 – Verify Deployment

### Wait ~3 minutes for the instance to bootstrap, then:

```bash
# Test the app in your browser
open http://YOUR_ELASTIC_IP

# Or test with curl
curl http://YOUR_ELASTIC_IP
curl http://YOUR_ELASTIC_IP/health

# SSH into the instance to debug if needed
ssh -i ~/.ssh/my-key-pair.pem ec2-user@YOUR_ELASTIC_IP

# Once SSH'd in, check logs:
pm2 logs my-app          # app logs
sudo systemctl status nginx  # nginx status
cat /var/log/bootstrap.log   # startup script log
```

---

## 🔄 Step 5 – CI/CD in Action

Every time you push to the `main` branch, GitHub Actions will automatically:

1. ✅ Run `npm test`
2. 🚀 SSH into your EC2 instance
3. 📥 `git pull` latest code
4. 🔄 `pm2 reload` (zero-downtime restart)
5. 🩺 Health check via `/health` endpoint

### To test CI/CD:
```bash
# Make a change to app/server.js
# Then push:
git add .
git commit -m "Update app"
git push origin main

# Watch it deploy:
# GitHub → your repo → Actions tab → see the workflow run
```

---

## 🧹 Cleanup – Avoid AWS Charges

When you're done, destroy everything:
```bash
cd terraform
terraform destroy
# Type: yes
```

This removes ALL resources and stops AWS billing.

---

## 💰 Cost Awareness

| Resource | Cost (approx.) |
|----------|---------------|
| t3.small EC2 | ~$0.023/hr ≈ $17/month |
| Elastic IP (when attached) | Free |
| Elastic IP (when NOT attached) | $0.005/hr – always destroy when unused! |
| Data transfer (first 100GB) | Free |
| **Total (dev usage)** | **~$17/month max** |

> 💡 **Free Tier:** New AWS accounts get 750 hrs/month of t2.micro FREE for 12 months.
> Change `instance_type = "t2.micro"` in tfvars to use it for free!

---

## 🎯 Design Decisions

| Decision | Why |
|----------|-----|
| **t3.small** | Burstable CPU, 2GB RAM – good for small apps |
| **Amazon Linux 2023** | AWS-native, well-supported, free |
| **PM2** | Keeps Node.js alive after crashes, enables zero-downtime reloads |
| **Nginx reverse proxy** | Handles port 80 → 3000 forwarding cleanly |
| **Elastic IP** | Prevents IP changing on instance stop/start |
| **GitHub Actions** | Free for public repos, tight GitHub integration |
| **Terraform** | Reproducible infra, easy to destroy/recreate |

## ⚖️ Trade-offs

| Trade-off | What we chose | Alternative |
|-----------|--------------|-------------|
| Simplicity vs HA | Single EC2 | Auto Scaling Group + Load Balancer |
| Speed vs Security | Open SSH (port 22) | AWS SSM Session Manager (no open port) |
| Self-managed vs Managed | EC2 + PM2 | AWS Elastic Beanstalk / ECS |
| HTTP vs HTTPS | HTTP only | Add ACM certificate + ALB for HTTPS |

---

## 🐛 Troubleshooting

**App not loading after Terraform:**
```bash
ssh -i ~/.ssh/my-key-pair.pem ec2-user@YOUR_IP
cat /var/log/bootstrap.log
pm2 status
sudo systemctl status nginx
```

**GitHub Actions failing with "Permission denied":**
- Check that `EC2_SSH_KEY` secret contains the full .pem file content
- Check that `EC2_HOST` secret has the correct IP

**`terraform apply` fails:**
- Run `aws sts get-caller-identity` to verify credentials
- Make sure your IAM user has AdministratorAccess

**Port 3000 not accessible:**
- Check Security Group in AWS Console → ensure inbound rule for port 3000 exists

