#!/bin/bash

# Docker Build Script with npm Rate Limiting Handling
# This script builds Docker images with robust npm retry logic

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
IMAGE_NAME=${IMAGE_NAME:-"tictactoe-app"}
TAG=${TAG:-"latest"}
DOCKERFILE=${DOCKERFILE:-"Dockerfile"}

# Auto-detect platform for local builds
if [ -z "$PLATFORM" ]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        PLATFORM="linux/arm64"
    else
        PLATFORM="linux/amd64"
    fi
fi

BUILD_ARGS=${BUILD_ARGS:-""}

# Function to check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    print_success "Docker is running"
}

# Function to build Docker image with retry logic
build_image() {
    local max_attempts=3
    local attempt=1
    local delay=10
    
    print_status "Building Docker image: $IMAGE_NAME:$TAG"
    print_status "Using Dockerfile: $DOCKERFILE"
    print_status "Platform: $PLATFORM"
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Build attempt $attempt of $max_attempts"
        
        if docker build \
            --platform $PLATFORM \
            --file $DOCKERFILE \
            --tag $IMAGE_NAME:$TAG \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            $BUILD_ARGS \
            .; then
            print_success "Docker image built successfully on attempt $attempt"
            return 0
        else
            print_warning "Build failed on attempt $attempt"
            
            if [ $attempt -eq $max_attempts ]; then
                print_error "All build attempts failed"
                return 1
            fi
            
            print_status "Waiting $delay seconds before retry..."
            sleep $delay
            attempt=$((attempt + 1))
            delay=$((delay * 2))
        fi
    done
}

# Function to test the built image
test_image() {
    print_status "Testing Docker image..."
    
    # Test if the image can start
    CONTAINER_ID=$(docker run -d --rm $IMAGE_NAME:$TAG)
    
    if [ $? -eq 0 ]; then
        print_status "Container started successfully, waiting for health check..."
        
        # Wait for health check
        sleep 30
        
        # Check if container is still running
        if docker ps | grep -q $CONTAINER_ID; then
            print_success "Docker image test passed"
            docker stop $CONTAINER_ID >/dev/null 2>&1
        else
            print_warning "Container stopped unexpectedly"
            docker logs $CONTAINER_ID
            docker stop $CONTAINER_ID >/dev/null 2>&1
            return 1
        fi
    else
        print_error "Failed to start container"
        return 1
    fi
}

# Function to show image information
show_image_info() {
    print_status "Docker image information:"
    
    docker images $IMAGE_NAME:$TAG --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    print_status "Image layers:"
    docker history $IMAGE_NAME:$TAG --format "table {{.CreatedBy}}\t{{.Size}}"
}

# Function to clean up old images
cleanup_images() {
    if [ "$CLEANUP" = "true" ]; then
        print_status "Cleaning up old images..."
        
        # Remove dangling images
        docker image prune -f
        
        # Remove old versions of this image
        docker images $IMAGE_NAME --format "{{.ID}}" | grep -v $(docker images $IMAGE_NAME:$TAG --format "{{.ID}}") | xargs -r docker rmi -f
        
        print_success "Cleanup completed"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --image-name NAME    - Docker image name (default: tictactoe-app)"
    echo "  --tag TAG           - Docker image tag (default: latest)"
    echo "  --dockerfile FILE   - Dockerfile to use (default: Dockerfile)"
    echo "  --platform PLATFORM - Target platform (default: linux/amd64)"
    echo "  --build-args ARGS   - Additional build arguments"
    echo "  --test              - Test the built image"
    echo "  --cleanup           - Clean up old images after build"
    echo "  --help              - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  IMAGE_NAME          - Docker image name"
    echo "  TAG                 - Docker image tag"
    echo "  DOCKERFILE          - Dockerfile to use"
    echo "  PLATFORM            - Target platform"
    echo "  BUILD_ARGS          - Additional build arguments"
    echo "  CLEANUP             - Set to 'true' to clean up old images"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --image-name myapp --tag v1.0.0"
    echo "  $0 --dockerfile Dockerfile.production --test"
    echo "  CLEANUP=true $0 --test"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --dockerfile)
            DOCKERFILE="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --build-args)
            BUILD_ARGS="$2"
            shift 2
            ;;
        --test)
            TEST_IMAGE=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main script logic
main() {
    print_status "Starting Docker build process..."
    
    check_docker
    build_image
    
    if [ "$TEST_IMAGE" = "true" ]; then
        test_image
    fi
    
    show_image_info
    cleanup_images
    
    print_success "Docker build process completed successfully!"
}

# Run main function
main
