# TicTacToe Full-Stack Application

A complete full-stack TicTacToe game application with backend, database, containerization, CI/CD pipeline, and auto-scaling capabilities.

## 🎯 Project Overview

This project transforms a simple TicTacToe game into a production-ready full-stack application with:

- **Frontend**: Modern, responsive web interface
- **Backend**: Node.js/Express.js REST API
- **Database**: SQLite with persistent storage
- **Containerization**: Docker with security best practices
- **Orchestration**: Kubernetes with auto-scaling (HPA)
- **CI/CD**: GitHub Actions automated pipeline
- **Load Testing**: k6 performance testing
- **Monitoring**: Health checks and observability

## 🏗️ Architecture

See [Architecture Diagram](architecture-diagram.md) for detailed system design and component interactions.

## 🚀 Quick Start

### Prerequisites

- Node.js 16+ 
- Docker
- Kubernetes cluster (minikube, Docker Desktop, or cloud provider)
- kubectl CLI tool

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TicTacGame-main
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Check and fix dependencies (if needed)**
   ```bash
   # Check if package-lock.json is in sync
   npm run check-deps
   
   # Fix package-lock.json if out of sync
   npm run fix-deps
   
   # Install dependencies with retry logic (handles rate limiting)
   npm run install-retry
   ```

4. **Build Docker image (with npm rate limiting handling)**
   ```bash
   # Build Docker image with retry logic
   npm run docker-build
   
   # Build and test Docker image
   npm run docker-build-test
   
   # Build production image with multi-stage build
   npm run docker-build-prod
   ```

5. **Run load tests**
   ```bash
   # Run load test (1 minute, 10 users)
   npm run load-test
   
   # Run quick load test (30 seconds, 5 users)
   npm run load-test-quick
   
   # Custom load test
   ./scripts/test-load.sh --url http://localhost:3000 --duration 2m --users 20
   ```

6. **Run security scans**
   ```bash
   # Run npm security audit
   npm audit
   
   # Run Trivy vulnerability scanner (if installed)
   trivy fs .
   
   # Security audit with specific level
   npm audit --audit-level=moderate
   ```

7. **Deploy to Kubernetes**
   ```bash
   # Full Kubernetes setup (deploy + verify + health check)
   npm run k8s-setup
   
   # Individual Kubernetes commands
   npm run k8s-deploy      # Deploy to Kubernetes
   npm run k8s-verify      # Verify deployment
   npm run k8s-health      # Run health checks
   npm run k8s-logs        # Show application logs
   npm run k8s-delete      # Delete deployment
   npm run k8s-kubeconfig  # Generate kubeconfig for GitHub Actions
   
   # Manual Kubernetes commands
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/deployment.yaml
   kubectl get pods -n tictactoe
   ```

8. **Start the development server**
   ```bash
   npm run dev
   ```

9. **Access the application**
   - Open http://localhost:3000 in your browser
   - Health check: http://localhost:3000/health

### Docker Deployment

#### Production (Docker Compose)
```bash
# Start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the application (graceful shutdown)
docker-compose down

# Force stop (if needed)
docker-compose down --timeout 0
```

#### Development (Docker Compose with Hot Reload)
```bash
# Start with nodemon for development
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop the application (graceful shutdown)
docker-compose -f docker-compose.dev.yml down

# Force stop (if needed)
docker-compose -f docker-compose.dev.yml down --timeout 0
```

#### Manual Docker Commands
1. **Build the Docker image**
   ```bash
   docker build -t tictactoe-app .
   ```

2. **Run the container**
   ```bash
   docker run -p 3000:3000 tictactoe-app
   ```

3. **Access the application**
   - Open http://localhost:3000 in your browser

### AWS Deployment

#### Prerequisites
- AWS CLI configured with appropriate permissions
- Docker installed and running
- Terraform (optional, for infrastructure as code)

#### Option 1: Manual AWS ECS Deployment

1. **Create ECR Repository**
   ```bash
   aws ecr create-repository --repository-name tictactoe-app --region us-east-1
   ```

2. **Build and Push Docker Image**
   ```bash
   # Get ECR login token
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
   
   # Build and tag image
   docker build -t tictactoe-app .
   docker tag tictactoe-app:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tictactoe-app:latest
   
   # Push to ECR
   docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tictactoe-app:latest
   ```

3. **Deploy using AWS Script**
   ```bash
   # Set your AWS account ID
   export AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID
   export AWS_REGION=us-east-1
   
   # Deploy to ECS
   ./aws/deploy.sh deploy
   ```

#### Option 2: Infrastructure as Code with Terraform

1. **Initialize Terraform**
   ```bash
   cd aws/terraform
   terraform init
   ```

2. **Plan and Apply**
   ```bash
   terraform plan
   terraform apply
   ```

3. **Deploy Application**
   ```bash
   # Build and push image
   docker build -t tictactoe-app .
   docker tag tictactoe-app:latest $(terraform output -raw ecr_repository_url):latest
   docker push $(terraform output -raw ecr_repository_url):latest
   ```

#### AWS Architecture
- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: Traffic distribution and SSL termination
- **ECR**: Container image registry
- **CloudWatch**: Logging and monitoring
- **VPC**: Network isolation and security
- **Auto Scaling**: Automatic scaling based on CPU, memory, and request count

#### Access the Application
After deployment, access your application at:
```
http://YOUR_ALB_DNS_NAME
```

#### Auto Scaling Configuration

The application includes comprehensive auto-scaling capabilities:

**Target Tracking Scaling:**
- **CPU-based**: Scales when CPU utilization exceeds 70%
- **Memory-based**: Scales when memory utilization exceeds 70%
- **Request Count**: Scales based on request count per target

**Scheduled Scaling:**
- **Scale Up**: 8 AM daily (2-8 instances)
- **Scale Down**: 10 PM daily (1-3 instances)

**Capacity Limits:**
- **Minimum**: 1 instance
- **Maximum**: 10 instances
- **Default**: 2 instances

**Management Commands:**
```bash
# Show auto-scaling status
./aws/manage-auto-scaling.sh status

# Update capacity limits
./aws/manage-auto-scaling.sh update-capacity 2 8

# Update CPU target
./aws/manage-auto-scaling.sh update-cpu-target 60

# Enable scheduled scaling
./aws/manage-auto-scaling.sh enable-scheduled

# Show CloudWatch alarms
./aws/manage-auto-scaling.sh alarms
```

**Auto Scaling Features:**
- ✅ **CPU-based scaling** (70% target)
- ✅ **Memory-based scaling** (70% target)
- ✅ **Request count scaling** (1000 requests/target)
- ✅ **Scheduled scaling** (configurable)
- ✅ **CloudWatch alarms** (CPU, memory, response time)
- ✅ **Cooldown periods** (5 minutes)
- ✅ **Stabilization windows** (prevent thrashing)

### CI/CD Pipeline

The project includes comprehensive CI/CD workflows:

#### **Automated Deployment (`deploy.yml`)**
- **Triggers**: Push to `main`/`develop`, tags, manual dispatch
- **Environments**: Development, Staging, Production
- **Features**:
  - Multi-node testing (18.x, 20.x)
  - Security scanning with Trivy
  - Docker image building with multi-platform support
  - Automated deployment to staging/production
  - Load testing with k6
  - Performance monitoring
  - Notifications and deployment summaries

#### **Simple Deployment (`simple-deploy.yml`)**
- **Triggers**: Push to `main`/`develop`, pull requests
- **Features**:
  - Basic testing and building
  - Single-platform Docker builds
  - Staging deployment
  - Works with user packages (no organization permissions needed)

#### **Manual Deployment (`manual-deploy.yml`)**
- **Triggers**: Manual workflow dispatch
- **Features**:
  - Deploy to any environment on-demand
  - Specify custom image tags
  - Force redeploy options
  - Validation and safety checks

#### **Emergency Rollback (`rollback.yml`)**
- **Triggers**: Manual workflow dispatch
- **Features**:
  - Quick rollback to previous versions
  - Environment-specific rollbacks
  - Safety validations
  - Rollback verification

#### **Workflow Usage**

**Automated Deployment:**
```bash
# Push to main branch for production deployment
git push origin main

# Push to develop branch for staging deployment
git push origin develop

# Create a release tag for production
git tag v1.0.0
git push origin v1.0.0
```

**Manual Deployment:**
1. Go to GitHub Actions → Manual Deployment
2. Click "Run workflow"
3. Select environment and options
4. Click "Run workflow"

**Emergency Rollback:**
1. Go to GitHub Actions → Emergency Rollback
2. Click "Run workflow"
3. Select environment and previous tag
4. Provide rollback reason
5. Click "Run workflow"


## 🧪 Testing

### Unit Tests
```bash
npm test
```

### Load Testing
```bash
# Install k6
# macOS: brew install k6
# Linux: sudo apt-get install k6

# Run load test
k6 run load-test.js
```

### API Testing
```bash
# Test health endpoint
curl http://localhost:3000/health

# Create a new game
curl -X POST http://localhost:3000/api/games

# Get game statistics
curl http://localhost:3000/api/stats
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
PORT=3000
NODE_ENV=production
```

### Graceful Shutdown

The application handles graceful shutdowns properly:

- **SIGTERM**: Docker sends this signal when stopping containers
- **SIGINT**: Ctrl+C sends this signal for manual interruption
- **Database**: SQLite connections are properly closed
- **HTTP Server**: Active connections are gracefully terminated
- **Timeout**: 10-second timeout before force shutdown

**Expected shutdown behavior:**
```
Received SIGTERM. Shutting down gracefully...
HTTP server closed.
Database connection closed.
Graceful shutdown completed.
```

### Kubernetes Configuration

The application uses the following Kubernetes resources:

- **Namespace**: `tictactoe`
- **Deployment**: 2 replicas with auto-scaling (2-10 pods)
- **Service**: LoadBalancer type
- **HPA**: CPU 70%, Memory 80% thresholds
- **PVC**: 1GB persistent storage

## 📊 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/` | Main application |
| POST | `/api/games` | Create new game |
| GET | `/api/games/:id` | Get game by ID |
| POST | `/api/games/:id/move` | Make a move |
| GET | `/api/games` | List all games |
| GET | `/api/stats` | Get player statistics |

### Example API Usage

```bash
# Create a new game
curl -X POST http://localhost:3000/api/games \
  -H "Content-Type: application/json"

# Make a move
curl -X POST http://localhost:3000/api/games/{game-id}/move \
  -H "Content-Type: application/json" \
  -d '{"position": 0, "player": "X"}'

# Get game state
curl http://localhost:3000/api/games/{game-id}

# Get statistics
curl http://localhost:3000/api/stats
```

## 🔄 CI/CD Pipeline

The GitHub Actions pipeline includes:

1. **Testing**: Jest unit tests on Node.js 16.x and 18.x
2. **Building**: Docker image build and push to registry
3. **Deployment**: Kubernetes deployment
4. **Load Testing**: k6 performance validation

### Pipeline Triggers

- Push to `main` branch: Full pipeline execution
- Push to `develop` branch: Testing only
- Pull requests: Testing only

### Required Secrets

Set up the following GitHub secrets:

- `KUBE_CONFIG`: Base64-encoded kubeconfig file

## 📈 Monitoring & Scaling

### Auto-scaling Configuration

- **Minimum replicas**: 2
- **Maximum replicas**: 10
- **CPU threshold**: 70%
- **Memory threshold**: 80%

### Health Checks

- **Liveness probe**: `/health` endpoint
- **Readiness probe**: `/health` endpoint
- **Initial delay**: 30s (liveness), 5s (readiness)
- **Period**: 10s (liveness), 5s (readiness)

### Resource Limits

- **CPU**: 100m request, 200m limit
- **Memory**: 128Mi request, 256Mi limit

## 🛡️ Security Features

- **Helmet.js**: Security headers
- **CORS**: Cross-origin resource sharing
- **Non-root container**: Docker security
- **Input validation**: API request validation
- **SQL injection prevention**: Parameterized queries

## 📁 Project Structure

```
TicTacGame-main/
├── public/                 # Frontend static files
│   ├── index.html         # Main HTML file
│   ├── style.css          # CSS styles
│   └── script.js          # Frontend JavaScript
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml     # Namespace definition
│   └── deployment.yaml    # Deployment, service, HPA
├── tests/                 # Test files
│   └── server.test.js     # Backend tests
├── .github/workflows/     # CI/CD pipeline
│   └── ci-cd.yml         # GitHub Actions workflow
├── server.js              # Backend server
├── package.json           # Node.js dependencies
├── Dockerfile             # Docker configuration
├── load-test.js           # k6 load test script
├── jest.config.js         # Jest configuration
└── README.md              # This file
```

## 🐛 Troubleshooting

### Common Issues

1. **npm ci failures in CI/CD**
   - **Error**: `npm ci` fails with package-lock.json sync issues
   - **Solution**: Run `npm run fix-deps` to update package-lock.json
   - **Prevention**: Run `npm run check-deps` before committing changes
   - **Note**: The CI/CD pipeline now automatically handles this issue

2. **npm rate limiting errors (HTTP 429)**
   - **Error**: `npm ERR! 429 Too Many Requests`
   - **Solution**: Use `npm run install-retry` for robust installation with retry logic
   - **Prevention**: The CI/CD pipeline uses retry logic to handle rate limiting
   - **Note**: The npm retry script automatically handles exponential backoff

3. **Docker build failures due to npm rate limiting**
   - **Error**: `npm error 429 Too Many Requests` during Docker build
   - **Solution**: Use `npm run docker-build` which includes retry logic
   - **Prevention**: Updated Dockerfile with npm configuration and retry logic
   - **Note**: Docker builds now automatically retry failed npm installations

4. **Docker container 500 errors on root endpoint**
   - **Error**: `ENOENT: no such file or directory, stat '/app/public/index.html'`
   - **Solution**: Fixed `.dockerignore` to include the `public` directory
   - **Prevention**: Updated `.dockerignore` to exclude only unnecessary files
   - **Note**: The `public` directory is now properly included in Docker builds

5. **Load test job failures in CI/CD**
   - **Error**: `curl: (7) Failed to connect to localhost port 3000`
   - **Solution**: Moved load test into the same job as deployment
   - **Prevention**: Load tests now run in the same environment as the application
   - **Note**: CI/CD workflows now properly handle service availability

6. **Security scanning permission errors**
   - **Error**: `Resource not accessible by integration` when uploading SARIF files
   - **Solution**: Added `security-events: write` permission to workflows
   - **Prevention**: Both CI/CD workflows now have proper security scanning permissions
   - **Note**: Trivy vulnerability scanning and SARIF upload now work correctly

7. **Database connection errors**
   - Ensure SQLite is properly initialized
   - Check file permissions for database file

8. **Kubernetes deployment issues**
   - **Error**: `connection refused` when trying to connect to cluster
   - **Solution**: Added proper cluster validation and KUBE_CONFIG secret handling
   - **Prevention**: Enhanced error handling and cluster connection verification
   - **Note**: Requires valid KUBE_CONFIG secret for production deployments

9. **General Kubernetes issues**
   - Verify cluster is running: `kubectl cluster-info`
   - Check pod logs: `kubectl logs -n tictactoe <pod-name>`
   - Verify service: `kubectl get svc -n tictactoe`

3. **Load testing failures**
   - Ensure application is accessible
   - Check network connectivity
   - Verify k6 installation

### Debug Commands

```bash
# Check application logs
kubectl logs -f deployment/tictactoe-app -n tictactoe

# Check HPA status
kubectl describe hpa tictactoe-hpa -n tictactoe

# Check resource usage
kubectl top pods -n tictactoe

# Port forward for debugging
kubectl port-forward pod/<pod-name> 3000:3000 -n tictactoe
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Original TicTacToe game implementation
- Node.js and Express.js communities
- Kubernetes and Docker documentation
- k6 load testing framework

---

**Note**: This is a demonstration project showcasing full-stack development, containerization, and DevOps practices. For production use, consider additional security measures, monitoring, and backup strategies.
