# 🎓 AWS Academy Cloud Operations - Complete Deployment Guide

## 📋 **Project Overview**

This guide deploys a complete **TicTacToe Full-Stack Application** on AWS Academy Cloud Operations - Sandbox Environment with:

- ✅ **EC2 Instance** (t2.micro - Free Tier)
- ✅ **Docker Containerization**
- ✅ **Load Testing** (k6 performance testing)
- ✅ **Auto-scaling** (Application Load Balancer + Auto Scaling Group)
- ✅ **Monitoring** (CloudWatch metrics and alarms)
- ✅ **Database** (SQLite with persistence)
- ✅ **Security** (Security Groups, IAM roles)

## 🚀 **Architecture Overview**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │───▶│  Auto Scaling   │───▶│   EC2 Instances │
│   (ALB)         │    │   Group (ASG)   │    │   (t2.micro)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │   Docker        │    │   SQLite        │
│   Monitoring    │    │   Containers    │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 **Step 1: AWS Academy Environment Setup**

### 1.1 Access AWS Academy Console
```bash
# Login to AWS Academy
# Go to: https://awsacademy.instructure.com/
# Navigate to Cloud Operations - Sandbox Environment
```

### 1.2 Configure AWS CLI
```bash
# Configure AWS CLI with Academy credentials
aws configure

# Enter your Academy credentials:
# AWS Access Key ID: [Your Academy Access Key]
# AWS Secret Access Key: [Your Academy Secret Key]
# Default region name: us-east-1
# Default output format: json
```

### 1.3 Verify Academy Access
```bash
# Test your Academy credentials
aws sts get-caller-identity

# Set environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=tictactoe-academy
```

## 🏗️ **Step 2: Infrastructure Setup**

### 2.1 Create VPC and Networking
```bash
# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
echo "Using VPC: $VPC_ID"

# Get default subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
SUBNET1=$(echo $SUBNET_IDS | cut -d' ' -f1)
SUBNET2=$(echo $SUBNET_IDS | cut -d' ' -f2)
echo "Using Subnets: $SUBNET1, $SUBNET2"
```

### 2.2 Create Security Groups
```bash
# Create security group for ALB
aws ec2 create-security-group \
  --group-name $PROJECT_NAME-alb-sg \
  --description "ALB Security Group for TicTacToe" \
  --vpc-id $VPC_ID

ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$PROJECT_NAME-alb-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

# Create security group for EC2 instances
aws ec2 create-security-group \
  --group-name $PROJECT_NAME-ec2-sg \
  --description "EC2 Security Group for TicTacToe" \
  --vpc-id $VPC_ID

EC2_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$PROJECT_NAME-ec2-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

# Add rules to ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Add rules to EC2 security group
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 3000 \
  --source-group $ALB_SG_ID

aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

### 2.3 Create Key Pair
```bash
# Create key pair for SSH access
aws ec2 create-key-pair \
  --key-name $PROJECT_NAME-key \
  --query 'KeyMaterial' \
  --output text > $PROJECT_NAME-key.pem

chmod 400 $PROJECT_NAME-key.pem
```

## 🐳 **Step 3: Docker Image Setup**

### 3.1 Create ECR Repository
```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name $PROJECT_NAME \
  --image-scanning-configuration scanOnPush=true

# Get ECR repository URI
ECR_URI=$(aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com)
ECR_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME
```

### 3.2 Build and Push Docker Image
```bash
# Build Docker image
docker build -t $PROJECT_NAME .

# Tag image for ECR
docker tag $PROJECT_NAME:latest $ECR_REPO_URI:latest

# Push to ECR
docker push $ECR_REPO_URI:latest
```

## 🚀 **Step 4: Launch Template and Auto Scaling**

### 4.1 Create Launch Template
```bash
# Get latest Amazon Linux 2 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query 'Images[0].ImageId' --output text)

# Create launch template
aws ec2 create-launch-template \
  --launch-template-name $PROJECT_NAME-lt \
  --version-description "Initial version" \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"t2.micro\",
    \"SecurityGroupIds\": [\"$EC2_SG_ID\"],
    \"UserData\": \"$(base64 -w 0 << 'EOF'
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URI
docker pull $ECR_REPO_URI:latest
docker run -d --name tictactoe-app -p 3000:3000 -v /home/ec2-user/data:/app/data $ECR_REPO_URI:latest
EOF
)\"
  }"
```

### 4.2 Create Auto Scaling Group
```bash
# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --launch-template LaunchTemplateName=$PROJECT_NAME-lt,Version='$Latest' \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier "$SUBNET1,$SUBNET2" \
  --target-group-arns [] \
  --health-check-type EC2 \
  --health-check-grace-period 300
```

## ⚖️ **Step 5: Load Balancer Setup**

### 5.1 Create Application Load Balancer
```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name $PROJECT_NAME-alb \
  --subnets $SUBNET1 $SUBNET2 \
  --security-groups $ALB_SG_ID

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names $PROJECT_NAME-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Create target group
aws elbv2 create-target-group \
  --name $PROJECT_NAME-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id $VPC_ID \
  --target-type instance \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2

# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names $PROJECT_NAME-tg \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

### 5.2 Attach Target Group to Auto Scaling Group
```bash
# Attach target group to ASG
aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --target-group-arns $TG_ARN
```

## 📊 **Step 6: Auto Scaling Policies**

### 6.1 Create CloudWatch Alarms
```bash
# Create CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name $PROJECT_NAME-cpu-alarm \
  --alarm-description "CPU utilization alarm" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 60 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions [] \
  --dimensions Name=AutoScalingGroupName,Value=$PROJECT_NAME-asg

# Create scale-out policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --policy-name $PROJECT_NAME-scale-out \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment 1 \
  --cooldown 300

# Create scale-in policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --policy-name $PROJECT_NAME-scale-in \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment -1 \
  --cooldown 300
```

## 🧪 **Step 7: Load Testing Setup**

### 7.1 Create Load Testing Script
```bash
# Create k6 load testing script
cat > load-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 }, // Ramp up to 10 users
    { duration: '5m', target: 10 }, // Stay at 10 users
    { duration: '2m', target: 0 },  // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.1'],     // Error rate must be below 10%
  },
};

const BASE_URL = 'http://YOUR_ALB_DNS_NAME';

export default function () {
  // Test health endpoint
  let healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, { 'health status is 200': (r) => r.status === 200 });

  // Test main page
  let mainRes = http.get(`${BASE_URL}/`);
  check(mainRes, { 'main page status is 200': (r) => r.status === 200 });

  // Test API endpoints
  let gamesRes = http.get(`${BASE_URL}/api/games`);
  check(gamesRes, { 'games API status is 200': (r) => r.status === 200 });

  // Create a new game
  let createRes = http.post(`${BASE_URL}/api/games`, JSON.stringify({}));
  check(createRes, { 'create game status is 201': (r) => r.status === 201 });

  sleep(1);
}
EOF
```

### 7.2 Run Load Tests
```bash
# Install k6 (if not already installed)
# macOS: brew install k6
# Ubuntu: sudo apt-get install k6

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names $PROJECT_NAME-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

# Update load test script with ALB DNS
sed -i "s/YOUR_ALB_DNS_NAME/$ALB_DNS/g" load-test.js

# Run load test
k6 run load-test.js
```

## 📈 **Step 8: Monitoring and Observability**

### 8.1 CloudWatch Dashboard
```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name $PROJECT_NAME-dashboard \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "x": 0,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "'$PROJECT_NAME-asg'"]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "'$AWS_REGION'",
          "title": "CPU Utilization"
        }
      },
      {
        "type": "metric",
        "x": 12,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "'$PROJECT_NAME-alb'"]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "'$AWS_REGION'",
          "title": "Request Count"
        }
      }
    ]
  }'
```

### 8.2 Set up Logging
```bash
# Create CloudWatch log group
aws logs create-log-group --log-group-name /aws/ec2/$PROJECT_NAME

# Configure log retention
aws logs put-retention-policy \
  --log-group-name /aws/ec2/$PROJECT_NAME \
  --retention-in-days 7
```

## 🎯 **Step 9: Application Testing**

### 9.1 Test Application Access
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names $PROJECT_NAME-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

echo "Application URL: http://$ALB_DNS"

# Test health endpoint
curl http://$ALB_DNS/health

# Test main application
curl http://$ALB_DNS/

# Test API endpoints
curl http://$ALB_DNS/api/games
```

### 9.2 Monitor Auto Scaling
```bash
# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $PROJECT_NAME-asg

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN
```

## 🧹 **Step 10: Cleanup**

### 10.1 Complete Cleanup Script
```bash
#!/bin/bash
# Cleanup script for AWS Academy resources

echo "🧹 Starting cleanup of AWS Academy resources..."

# Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --force-delete

# Delete Launch Template
aws ec2 delete-launch-template \
  --launch-template-name $PROJECT_NAME-lt

# Delete Load Balancer
aws elbv2 delete-load-balancer \
  --load-balancer-arn $ALB_ARN

# Delete Target Group
aws elbv2 delete-target-group \
  --target-group-arn $TG_ARN

# Delete Security Groups
aws ec2 delete-security-group --group-id $ALB_SG_ID
aws ec2 delete-security-group --group-id $EC2_SG_ID

# Delete ECR Repository
aws ecr delete-repository \
  --repository-name $PROJECT_NAME \
  --force

# Delete Key Pair
aws ec2 delete-key-pair --key-name $PROJECT_NAME-key
rm -f $PROJECT_NAME-key.pem

# Delete CloudWatch Dashboard
aws cloudwatch delete-dashboards \
  --dashboard-names $PROJECT_NAME-dashboard

# Delete CloudWatch Log Group
aws logs delete-log-group \
  --log-group-name /aws/ec2/$PROJECT_NAME

echo "✅ Cleanup completed successfully!"
```

## 📊 **Resource Usage and Cost Analysis**

| Resource | Type | Quantity | Estimated Cost |
|----------|------|----------|----------------|
| EC2 Instances | t2.micro | 1-3 (auto-scaling) | $8.47/month each |
| Application Load Balancer | ALB | 1 | $16.20/month |
| ECR Repository | Storage | ~100MB | $0.10/month |
| CloudWatch | Monitoring | Basic | $0.30/month |
| **Total Estimated Cost** | | | **~$25-50/month** |

## 🎓 **Academy Best Practices**

### 10.1 Resource Management
- ✅ **Use Free Tier** when possible (t2.micro instances)
- ✅ **Monitor costs** regularly in Academy console
- ✅ **Clean up resources** before session ends
- ✅ **Document everything** for submission

### 10.2 Performance Optimization
- ✅ **Auto-scaling** based on CPU utilization
- ✅ **Load balancing** for high availability
- ✅ **Health checks** for reliability
- ✅ **Monitoring** with CloudWatch

### 10.3 Security Best Practices
- ✅ **Security groups** with minimal required access
- ✅ **IAM roles** for least privilege access
- ✅ **VPC isolation** using default VPC
- ✅ **Key pair management** for SSH access

## 📝 **Submission Checklist**

### Required Documentation
- [ ] Complete deployment process documented
- [ ] Architecture diagram included
- [ ] Load testing results
- [ ] Auto-scaling demonstration
- [ ] Cost analysis completed
- [ ] Screenshots of all components
- [ ] Cleanup process documented

### Required Screenshots
- [ ] AWS Academy console access
- [ ] ECR repository with Docker image
- [ ] Auto Scaling Group configuration
- [ ] Load Balancer setup
- [ ] CloudWatch dashboard
- [ ] Load testing results
- [ ] Application running successfully
- [ ] Cleanup completed

---

## 🚀 **Quick Start Commands**

```bash
# 1. Set up environment
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=tictactoe-academy

# 2. Run complete deployment
./aws/deploy-complete-academy.sh deploy

# 3. Run load testing
./aws/run-load-tests.sh

# 4. Monitor application
./aws/monitor-academy.sh

# 5. Cleanup when done
./aws/cleanup-academy.sh
```

**Good luck with your comprehensive AWS Academy deployment!** 🎓
