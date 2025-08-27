# 🎓 AWS Academy Complete Deployment Quick Reference

## 🚀 **Complete Architecture Overview**

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

## 📋 **Services Used**

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **EC2** | Application hosting | t2.micro (Free Tier) |
| **Docker** | Containerization | ECR repository |
| **Load Testing** | Performance testing | k6 with k6 Cloud |
| **Auto-scaling** | Scalability | ASG with ALB |
| **Load Balancer** | Traffic distribution | Application Load Balancer |
| **CloudWatch** | Monitoring | Metrics, alarms, dashboards |
| **ECR** | Container registry | Docker image storage |
| **VPC** | Networking | Default VPC with subnets |
| **Security Groups** | Security | ALB and EC2 rules |

## 🚀 **Step-by-Step Deployment**

### **Step 1: Environment Setup**
```bash
# Configure AWS CLI
aws configure

# Set environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=tictactoe-academy

# Verify access
aws sts get-caller-identity
```

### **Step 2: Infrastructure Creation**
```bash
# Get VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
SUBNET1=$(echo $SUBNET_IDS | cut -d' ' -f1)
SUBNET2=$(echo $SUBNET_IDS | cut -d' ' -f2)

# Create security groups
aws ec2 create-security-group --group-name $PROJECT_NAME-alb-sg --description "ALB Security Group" --vpc-id $VPC_ID
aws ec2 create-security-group --group-name $PROJECT_NAME-ec2-sg --description "EC2 Security Group" --vpc-id $VPC_ID

# Create key pair
aws ec2 create-key-pair --key-name $PROJECT_NAME-key --query 'KeyMaterial' --output text > $PROJECT_NAME-key.pem
chmod 400 $PROJECT_NAME-key.pem
```

### **Step 3: Docker Setup**
```bash
# Create ECR repository
aws ecr create-repository --repository-name $PROJECT_NAME --image-scanning-configuration scanOnPush=true

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push image
docker build -t $PROJECT_NAME .
docker tag $PROJECT_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:latest
```

### **Step 4: Auto Scaling Setup**
```bash
# Get AMI
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" --query 'Images[0].ImageId' --output text)

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

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --launch-template LaunchTemplateName=$PROJECT_NAME-lt,Version='$Latest' \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier "$SUBNET1,$SUBNET2" \
  --health-check-type EC2 \
  --health-check-grace-period 300
```

### **Step 5: Load Balancer Setup**
```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name $PROJECT_NAME-alb \
  --subnets $SUBNET1 $SUBNET2 \
  --security-groups $ALB_SG_ID

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

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Attach to ASG
aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --target-group-arns $TG_ARN
```

### **Step 6: Auto Scaling Policies**
```bash
# Create CloudWatch alarm
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
  --dimensions Name=AutoScalingGroupName,Value=$PROJECT_NAME-asg

# Create scaling policies
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --policy-name $PROJECT_NAME-scale-out \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment 1 \
  --cooldown 300

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --policy-name $PROJECT_NAME-scale-in \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment -1 \
  --cooldown 300
```

### **Step 7: Load Testing Setup**
```bash
# Create k6 load test script
cat > load-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.1'],
  },
};

const BASE_URL = 'http://YOUR_ALB_DNS_NAME';

export default function () {
  let healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, { 'health status is 200': (r) => r.status === 200 });

  let mainRes = http.get(`${BASE_URL}/`);
  check(mainRes, { 'main page status is 200': (r) => r.status === 200 });

  let gamesRes = http.get(`${BASE_URL}/api/games`);
  check(gamesRes, { 'games API status is 200': (r) => r.status === 200 });

  let createRes = http.post(`${BASE_URL}/api/games`, JSON.stringify({}));
  check(createRes, { 'create game status is 201': (r) => r.status === 201 });

  sleep(1);
}
EOF

# Get ALB DNS and update script
ALB_DNS=$(aws elbv2 describe-load-balancers --names $PROJECT_NAME-alb --query 'LoadBalancers[0].DNSName' --output text)
sed -i "s/YOUR_ALB_DNS_NAME/$ALB_DNS/g" load-test.js

# Run load test
k6 run load-test.js
```

### **Step 8: Monitoring Setup**
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

# Create log group
aws logs create-log-group --log-group-name /aws/ec2/$PROJECT_NAME
aws logs put-retention-policy --log-group-name /aws/ec2/$PROJECT_NAME --retention-in-days 7
```

## 📊 **Resource Usage and Costs**

| Resource | Type | Quantity | Cost/Month |
|----------|------|----------|------------|
| EC2 Instances | t2.micro | 1-3 (auto-scaling) | $8.47 each |
| Application Load Balancer | ALB | 1 | $16.20 |
| ECR Repository | Storage | ~100MB | $0.10 |
| CloudWatch | Monitoring | Basic | $0.30 |
| **Total Estimated** | | | **~$25-50** |

## 🧪 **Load Testing Commands**

### **Basic Load Test**
```bash
# Install k6
# macOS: brew install k6
# Ubuntu: sudo apt-get install k6

# Run basic test
k6 run load-test.js
```

### **Stress Test**
```bash
# Create stress test
cat > stress-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 5 },
    { duration: '2m', target: 20 },
    { duration: '2m', target: 20 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.05'],
  },
};

const BASE_URL = 'http://YOUR_ALB_DNS_NAME';

export default function () {
  let responses = http.batch([
    ['GET', `${BASE_URL}/health`],
    ['GET', `${BASE_URL}/`],
    ['GET', `${BASE_URL}/api/games`],
    ['POST', `${BASE_URL}/api/games`, null, { headers: { 'Content-Type': 'application/json' } }],
  ]);

  responses.forEach((response, index) => {
    check(response, { [`request ${index} status is 200/201`]: (r) => r.status === 200 || r.status === 201 });
  });

  sleep(1);
}
EOF

# Run stress test
k6 run stress-test.js
```

### **Spike Test**
```bash
# Create spike test
cat > spike-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 5 },
    { duration: '30s', target: 50 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 5 },
    { duration: '1m', target: 0 },
  ],
};

const BASE_URL = 'http://YOUR_ALB_DNS_NAME';

export default function () {
  let res = http.get(`${BASE_URL}/health`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
EOF

# Run spike test
k6 run spike-test.js
```

## 📈 **Monitoring Commands**

### **Check Application Status**
```bash
# Get ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers --names $PROJECT_NAME-alb --query 'LoadBalancers[0].DNSName' --output text)

# Test endpoints
curl http://$ALB_DNS/health
curl http://$ALB_DNS/
curl http://$ALB_DNS/api/games
```

### **Monitor Auto Scaling**
```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $PROJECT_NAME-asg

# Check target group health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names $PROJECT_NAME-cpu-alarm
```

### **View Logs**
```bash
# List log streams
aws logs describe-log-streams --log-group-name /aws/ec2/$PROJECT_NAME

# Get recent logs
aws logs get-log-events \
  --log-group-name /aws/ec2/$PROJECT_NAME \
  --log-stream-name [STREAM_NAME]
```

## 🧹 **Cleanup Commands**

### **Complete Cleanup**
```bash
#!/bin/bash
echo "🧹 Starting cleanup..."

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

# Delete CloudWatch resources
aws cloudwatch delete-dashboards --dashboard-names $PROJECT_NAME-dashboard
aws logs delete-log-group --log-group-name /aws/ec2/$PROJECT_NAME

echo "✅ Cleanup completed!"
```

## 🎯 **Quick Commands Reference**

### **Deployment**
```bash
# Full deployment
./aws/deploy-complete-academy.sh deploy

# Check status
./aws/check-status.sh

# Get application URL
ALB_DNS=$(aws elbv2 describe-load-balancers --names $PROJECT_NAME-alb --query 'LoadBalancers[0].DNSName' --output text)
echo "http://$ALB_DNS"
```

### **Testing**
```bash
# Run load tests
k6 run load-test.js

# Run stress tests
k6 run stress-test.js

# Test API endpoints
curl http://$ALB_DNS/health
curl http://$ALB_DNS/api/games
```

### **Monitoring**
```bash
# Check ASG
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $PROJECT_NAME-asg

# Check ALB
aws elbv2 describe-load-balancers --names $PROJECT_NAME-alb

# Check CloudWatch
aws cloudwatch describe-alarms --alarm-names $PROJECT_NAME-cpu-alarm
```

### **Cleanup**
```bash
# Complete cleanup
./aws/cleanup-academy.sh

# Quick stop (scale to 0)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $PROJECT_NAME-asg \
  --desired-capacity 0
```

## 📝 **Academy Submission Checklist**

### **Required Screenshots**
- [ ] AWS Academy console access
- [ ] ECR repository with Docker image
- [ ] Auto Scaling Group configuration
- [ ] Load Balancer setup
- [ ] CloudWatch dashboard
- [ ] Load testing results
- [ ] Application running successfully
- [ ] Auto-scaling demonstration
- [ ] Cleanup completed

### **Required Documentation**
- [ ] Complete deployment process
- [ ] Architecture diagram
- [ ] Load testing results
- [ ] Auto-scaling demonstration
- [ ] Cost analysis
- [ ] Performance metrics
- [ ] Security configuration
- [ ] Monitoring setup

---

## 🚀 **One-Command Deployment**

```bash
# Complete deployment with all services
curl -sSL https://raw.githubusercontent.com/your-repo/deploy-academy.sh | bash -s deploy

# Complete cleanup
curl -sSL https://raw.githubusercontent.com/your-repo/cleanup-academy.sh | bash -s cleanup
```

**Good luck with your comprehensive AWS Academy deployment!** 🎓
