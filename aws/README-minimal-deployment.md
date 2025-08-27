# 🚀 Minimal Cost AWS Deployment Guide

This guide will help you deploy the TicTacToe application to AWS with minimal resource usage and cost.

## 💰 Cost Optimization Features

- **Minimal Resources**: 128 vCPU units (0.125 vCPU) and 256 MB RAM
- **Single Instance**: Runs only 1 instance by default
- **Auto-scaling**: Scales 1-3 instances only when needed
- **Estimated Cost**: ~$15-25 USD per month
- **Easy Cleanup**: Simple command to stop all costs

## 📋 Prerequisites

1. **AWS Account**: You need an AWS account
2. **AWS CLI**: Install and configure AWS CLI
3. **Docker**: Install Docker on your machine
4. **AWS Account ID**: Your 12-digit AWS account ID

## 🔧 Setup Steps

### 1. Install AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configure AWS CLI
```bash
aws configure
```
Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (use `us-east-1` for best pricing)
- Default output format (`json`)

### 3. Get Your AWS Account ID
```bash
aws sts get-caller-identity --query Account --output text
```

## 🚀 Deploy to AWS

### Quick Deployment
```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=YOUR_12_DIGIT_ACCOUNT_ID

# Deploy with minimal resources
./aws/deploy-minimal.sh deploy
```

### Step-by-Step Deployment

1. **Navigate to project directory**:
   ```bash
   cd TicTacToc-upgrade-version
   ```

2. **Set your AWS account ID**:
   ```bash
   export AWS_ACCOUNT_ID=123456789012  # Replace with your actual account ID
   ```

3. **Deploy the application**:
   ```bash
   ./aws/deploy-minimal.sh deploy
   ```

4. **Wait for deployment** (takes 5-10 minutes):
   - Docker image build and push
   - ECS cluster creation
   - Service deployment
   - Health checks

## 📊 Resource Usage

| Resource | Amount | Cost Impact |
|----------|--------|-------------|
| CPU | 128 vCPU units (0.125 vCPU) | Minimal |
| Memory | 256 MB | Minimal |
| Instances | 1 (default) | Minimal |
| Auto-scaling | 1-3 instances | Only when needed |
| Storage | ECR repository | ~$0.10/month |

## 🔍 Monitor Your Deployment

### Check Service Status
```bash
aws ecs describe-services \
  --cluster tictactoe-cluster-minimal \
  --services tictactoe-service-minimal \
  --region us-east-1
```

### View Application Logs
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/tictactoe-app-minimal \
  --region us-east-1
```

### Get Service URL
```bash
aws ecs describe-services \
  --cluster tictactoe-cluster-minimal \
  --services tictactoe-service-minimal \
  --region us-east-1 \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.assignPublicIp'
```

## 💡 Cost-Saving Tips

### 1. Scale Down When Not in Use
```bash
# Scale to 0 instances (stops all costs)
aws ecs update-service \
  --cluster tictactoe-cluster-minimal \
  --service tictactoe-service-minimal \
  --desired-count 0 \
  --region us-east-1
```

### 2. Scale Up When Needed
```bash
# Scale back to 1 instance
aws ecs update-service \
  --cluster tictactoe-cluster-minimal \
  --service tictactoe-service-minimal \
  --desired-count 1 \
  --region us-east-1
```

### 3. Monitor Costs
- Set up AWS Cost Explorer
- Create billing alerts
- Use AWS Budgets

## 🧹 Cleanup (Stop All Costs)

### Quick Cleanup
```bash
./aws/deploy-minimal.sh cleanup
```

### Manual Cleanup
```bash
# Stop the service
aws ecs update-service \
  --cluster tictactoe-cluster-minimal \
  --service tictactoe-service-minimal \
  --desired-count 0 \
  --region us-east-1

# Delete the service
aws ecs delete-service \
  --cluster tictactoe-cluster-minimal \
  --service tictactoe-service-minimal \
  --region us-east-1

# Delete the cluster
aws ecs delete-cluster \
  --cluster tictactoe-cluster-minimal \
  --region us-east-1

# Delete ECR repository
aws ecr delete-repository \
  --repository-name tictactoe-app-minimal \
  --force \
  --region us-east-1
```

## 🔧 Troubleshooting

### Common Issues

1. **AWS CLI not configured**
   ```bash
   aws configure
   ```

2. **Permission denied errors**
   - Ensure your AWS user has ECS, ECR, and IAM permissions
   - Use an IAM user with AdministratorAccess for testing

3. **Docker build failures**
   ```bash
   # Test Docker build locally first
   docker build -t tictactoe-app .
   ```

4. **Service not starting**
   ```bash
   # Check service events
   aws ecs describe-services \
     --cluster tictactoe-cluster-minimal \
     --services tictactoe-service-minimal \
     --region us-east-1 \
     --query 'services[0].events'
   ```

### Get Help
```bash
# Show deployment info
./aws/deploy-minimal.sh info

# Show usage
./aws/deploy-minimal.sh
```

## 📈 Scaling Options

### Auto-scaling (Automatic)
- CPU > 80%: Scale up
- Memory > 80%: Scale up
- Minimum: 1 instance
- Maximum: 3 instances

### Manual Scaling
```bash
# Scale to specific number
aws ecs update-service \
  --cluster tictactoe-cluster-minimal \
  --service tictactoe-service-minimal \
  --desired-count 2 \
  --region us-east-1
```

## 🎯 Next Steps

1. **Set up a domain** (optional)
2. **Configure SSL certificate**
3. **Set up monitoring and alerts**
4. **Create backup strategies**

## 💰 Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| ECS Fargate | ~$15-20 | 1 instance, minimal resources |
| ECR Storage | ~$0.10 | Docker image storage |
| CloudWatch Logs | ~$1-5 | Application logs |
| **Total** | **~$15-25** | Minimal cost deployment |

---

**Note**: This deployment is optimized for minimal cost while maintaining functionality. For production use, consider additional security measures and monitoring.
