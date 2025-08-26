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

3. **Start the development server**
   ```bash
   npm run dev
   ```

4. **Access the application**
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

1. **Database connection errors**
   - Ensure SQLite is properly initialized
   - Check file permissions for database file

2. **Kubernetes deployment issues**
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
