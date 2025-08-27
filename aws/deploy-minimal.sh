#!/bin/bash

# AWS ECS Minimal Cost Deployment Script for TicTacToe Application
# Optimized for minimal resource usage and cost

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Minimal Configuration for Cost Optimization
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REPOSITORY=${ECR_REPOSITORY:-"tictactoe-app-minimal"}
ECS_CLUSTER=${ECS_CLUSTER:-"tictactoe-cluster-minimal"}
ECS_SERVICE=${ECS_SERVICE:-"tictactoe-service-minimal"}
TASK_DEFINITION=${TASK_DEFINITION:-"tictactoe-app-minimal"}

# Function to check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to create ECR repository if it doesn't exist
create_ecr_repository() {
    print_status "Checking ECR repository..."
    
    if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION >/dev/null 2>&1; then
        print_status "Creating ECR repository..."
        aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
        print_success "ECR repository created"
    else
        print_success "ECR repository already exists"
    fi
}

# Function to build and push Docker image to ECR
build_and_push_image() {
    print_status "Building and pushing Docker image to ECR..."
    
    # Get ECR login token
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Build Docker image
    docker build -t $ECR_REPOSITORY .
    
    # Tag image for ECR
    docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    
    # Push to ECR
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    
    print_success "Docker image pushed to ECR"
}

# Function to create ECS cluster if it doesn't exist
create_ecs_cluster() {
    print_status "Checking ECS cluster..."
    
    if ! aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION >/dev/null 2>&1; then
        print_status "Creating ECS cluster..."
        aws ecs create-cluster --cluster-name $ECS_CLUSTER --region $AWS_REGION
        print_success "ECS cluster created"
    else
        print_success "ECS cluster already exists"
    fi
}

# Function to update ECS task definition with minimal resources
update_task_definition() {
    print_status "Updating ECS task definition with minimal resources..."
    
    # Update the task definition file with actual values
    sed -i.bak "s/YOUR_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" aws/ecs-task-definition-minimal.json
    sed -i.bak "s|YOUR_ECR_REPOSITORY_URL|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY|g" aws/ecs-task-definition-minimal.json
    
    # Register new task definition
    aws ecs register-task-definition \
        --cli-input-json file://aws/ecs-task-definition-minimal.json \
        --region $AWS_REGION
    
    print_success "Task definition updated with minimal resources"
}

# Function to create ECS service
create_service() {
    print_status "Creating ECS service..."
    
    # Get latest task definition revision
    TASK_DEFINITION_REVISION=$(aws ecs describe-task-definition \
        --task-definition $TASK_DEFINITION \
        --region $AWS_REGION \
        --query 'taskDefinition.revision' \
        --output text)
    
    # Create service with minimal configuration
    aws ecs create-service \
        --cluster $ECS_CLUSTER \
        --service-name $ECS_SERVICE \
        --task-definition $TASK_DEFINITION:$TASK_DEFINITION_REVISION \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
        --region $AWS_REGION
    
    print_success "ECS service created with minimal resources"
}

# Function to show deployment info
show_deployment_info() {
    print_success "Deployment completed successfully!"
    echo ""
    echo "📊 Resource Usage (Minimal Cost):"
    echo "   • CPU: 128 vCPU units (0.125 vCPU)"
    echo "   • Memory: 256 MB"
    echo "   • Instances: 1 (minimum)"
    echo "   • Auto-scaling: 1-3 instances"
    echo ""
    echo "💰 Estimated Monthly Cost: ~$15-25 USD"
    echo ""
    echo "🔗 To access your application:"
    echo "   • Check the ECS service for the public IP"
    echo "   • Or set up an Application Load Balancer for a domain"
    echo ""
    echo "📝 Useful commands:"
    echo "   • View service: aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
    echo "   • View logs: aws logs describe-log-groups --log-group-name-prefix /ecs/tictactoe-app-minimal --region $AWS_REGION"
    echo "   • Scale down: aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count 0 --region $AWS_REGION"
}

# Function to deploy
deploy() {
    print_status "Starting minimal cost deployment..."
    
    check_aws_config
    create_ecr_repository
    build_and_push_image
    create_ecs_cluster
    update_task_definition
    create_service
    show_deployment_info
}

# Function to show usage
usage() {
    echo "Usage: $0 {deploy|info|cleanup}"
    echo ""
    echo "Commands:"
    echo "  deploy    - Deploy the application with minimal resources"
    echo "  info      - Show deployment information"
    echo "  cleanup   - Remove all AWS resources (to stop costs)"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCOUNT_ID     - AWS account ID (required)"
    echo "  AWS_REGION         - AWS region (default: us-east-1)"
    echo ""
    echo "Example:"
    echo "  AWS_ACCOUNT_ID=123456789012 $0 deploy"
}

# Function to cleanup resources
cleanup() {
    print_warning "This will remove all AWS resources and stop all costs!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up AWS resources..."
        
        # Stop ECS service
        aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count 0 --region $AWS_REGION
        
        # Delete ECS service
        aws ecs delete-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --region $AWS_REGION
        
        # Delete ECS cluster
        aws ecs delete-cluster --cluster $ECS_CLUSTER --region $AWS_REGION
        
        # Delete ECR repository
        aws ecr delete-repository --repository-name $ECR_REPOSITORY --force --region $AWS_REGION
        
        print_success "All resources cleaned up. Costs stopped."
    else
        print_status "Cleanup cancelled."
    fi
}

# Main script logic
case "$1" in
    deploy)
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            print_error "AWS_ACCOUNT_ID environment variable is required"
            echo "Example: AWS_ACCOUNT_ID=123456789012 $0 deploy"
            exit 1
        fi
        deploy
        ;;
    info)
        show_deployment_info
        ;;
    cleanup)
        cleanup
        ;;
    *)
        usage
        exit 1
        ;;
esac
