#!/bin/bash

# Kubernetes Setup Script for TicTacToe Application
# This script helps set up and manage Kubernetes deployments

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

# Configuration
NAMESPACE="tictactoe"
DEPLOYMENT_NAME="tictactoe-app"
SERVICE_NAME="tictactoe-service"

# Function to check if kubectl is installed
check_kubectl() {
    print_status "Checking kubectl installation..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed. Please install kubectl first."
        print_status "Installation guide: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    print_success "kubectl is available"
}

# Function to check cluster connection
check_cluster() {
    print_status "Checking cluster connection..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please ensure you have a cluster running and kubectl is configured"
        print_status "For local development, you can use:"
        print_status "  - Docker Desktop with Kubernetes enabled"
        print_status "  - Minikube: minikube start"
        print_status "  - Kind: kind create cluster"
        exit 1
    fi
    
    print_success "Connected to Kubernetes cluster"
}

# Function to build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Build the image
    docker build -t ghcr.io/porchportal/tictactoe-app:latest .
    
    # Push to registry (requires authentication)
    if docker push ghcr.io/porchportal/tictactoe-app:latest; then
        print_success "Image pushed successfully"
    else
        print_warning "Failed to push image. You may need to authenticate with the registry."
        print_status "You can still deploy locally if the image exists locally."
    fi
}

# Function to deploy to Kubernetes
deploy_to_k8s() {
    print_status "Deploying to Kubernetes..."
    
    # Create namespace
    print_status "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    # Apply deployment
    print_status "Applying deployment..."
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment
    print_status "Waiting for deployment rollout..."
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s
    
    print_success "Deployment completed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check pods
    print_status "Checking pods..."
    kubectl get pods -n $NAMESPACE
    
    # Check services
    print_status "Checking services..."
    kubectl get services -n $NAMESPACE
    
    # Check HPA
    print_status "Checking Horizontal Pod Autoscaler..."
    kubectl get hpa -n $NAMESPACE
    
    print_success "Deployment verification completed"
}

# Function to get service URL
get_service_url() {
    print_status "Getting service URL..."
    
    # Wait for service to be ready
    kubectl wait --for=condition=ready pod -l app=$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s
    
    # Get LoadBalancer IP
    SERVICE_URL=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ]; then
        print_warning "LoadBalancer IP not available, trying NodePort..."
        SERVICE_URL=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        if [ -n "$SERVICE_URL" ]; then
            PORT=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "3000")
            SERVICE_URL="$SERVICE_URL:$PORT"
        fi
    fi
    
    if [ -z "$SERVICE_URL" ]; then
        print_error "Could not determine service URL"
        return 1
    fi
    
    print_success "Service URL: http://$SERVICE_URL"
    echo "http://$SERVICE_URL"
}

# Function to run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    SERVICE_URL=$(get_service_url)
    if [ $? -ne 0 ]; then
        print_error "Cannot get service URL for health checks"
        return 1
    fi
    
    # Health check
    print_status "Testing health endpoint..."
    for i in {1..30}; do
        if curl -s "http://$SERVICE_URL/health" >/dev/null 2>&1; then
            print_success "Health check passed!"
            break
        fi
        print_status "Attempt $i/30: Service not ready yet..."
        sleep 5
    done
    
    # Test main application
    print_status "Testing main application..."
    curl -f "http://$SERVICE_URL/" -o /dev/null -w "HTTP Status: %{http_code}\n"
    
    print_success "Health checks completed"
}

# Function to show logs
show_logs() {
    print_status "Showing application logs..."
    kubectl logs -f deployment/$DEPLOYMENT_NAME -n $NAMESPACE
}

# Function to delete deployment
delete_deployment() {
    print_status "Deleting deployment..."
    
    kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s/namespace.yaml --ignore-not-found=true
    
    print_success "Deployment deleted"
}

# Function to generate kubeconfig for GitHub Actions
generate_kubeconfig() {
    print_status "Generating kubeconfig for GitHub Actions..."
    
    # Generate base64 encoded kubeconfig
    KUBECONFIG_B64=$(kubectl config view --minify --flatten | base64)
    
    print_success "Kubeconfig generated"
    print_status "Add this as a secret named 'KUBE_CONFIG' in your GitHub repository:"
    echo ""
    echo "$KUBECONFIG_B64"
    echo ""
    print_status "Repository Settings > Secrets and variables > Actions > New repository secret"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy          - Deploy the application to Kubernetes"
    echo "  verify          - Verify the deployment"
    echo "  health          - Run health checks"
    echo "  logs            - Show application logs"
    echo "  delete          - Delete the deployment"
    echo "  build           - Build and push Docker image"
    echo "  kubeconfig      - Generate kubeconfig for GitHub Actions"
    echo "  setup           - Full setup (check + deploy + verify)"
    echo "  help            - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 setup"
    echo "  $0 health"
}

# Main script logic
main() {
    case "${1:-help}" in
        deploy)
            check_kubectl
            check_cluster
            deploy_to_k8s
            ;;
        verify)
            check_kubectl
            check_cluster
            verify_deployment
            ;;
        health)
            check_kubectl
            check_cluster
            run_health_checks
            ;;
        logs)
            check_kubectl
            check_cluster
            show_logs
            ;;
        delete)
            check_kubectl
            check_cluster
            delete_deployment
            ;;
        build)
            build_and_push_image
            ;;
        kubeconfig)
            check_kubectl
            check_cluster
            generate_kubeconfig
            ;;
        setup)
            check_kubectl
            check_cluster
            deploy_to_k8s
            verify_deployment
            run_health_checks
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
