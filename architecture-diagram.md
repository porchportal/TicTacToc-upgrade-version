# TicTacToe Full-Stack Application Architecture

## System Overview

This is a full-stack TicTacToe game application with the following components:

### Frontend (Client-Side)
- **Technology**: HTML5, CSS3, JavaScript (ES6+)
- **Location**: `public/` directory
- **Features**:
  - Responsive game interface
  - Dark/Light mode toggle
  - Real-time game state updates
  - Player statistics display
  - Error handling and user feedback

### Backend (Server-Side)
- **Technology**: Node.js, Express.js
- **Location**: `server.js`
- **Features**:
  - RESTful API endpoints
  - Game logic and state management
  - Database operations
  - Security middleware (Helmet, CORS)
  - Request logging (Morgan)
  - Health check endpoint

### Database
- **Technology**: SQLite3
- **Location**: `tictactoe.db`
- **Tables**:
  - `games`: Stores game state and metadata
  - `moves`: Tracks individual moves for audit trail
  - `player_stats`: Maintains player win/loss/draw statistics

### Containerization
- **Technology**: Docker
- **Location**: `Dockerfile`
- **Features**:
  - Multi-stage build for optimization
  - Non-root user for security
  - Health checks
  - Alpine Linux base for minimal size

### Orchestration & Scaling
- **Technology**: Kubernetes
- **Location**: `k8s/` directory
- **Components**:
  - Deployment with auto-scaling (HPA)
  - LoadBalancer service
  - Persistent volume for database
  - Resource limits and requests
  - Health probes

### CI/CD Pipeline
- **Technology**: GitHub Actions
- **Location**: `.github/workflows/ci-cd.yml`
- **Stages**:
  1. Testing (Node.js 16.x, 18.x)
  2. Building Docker image
  3. Deploying to Kubernetes
  4. Load testing with k6

### Load Testing
- **Technology**: k6
- **Location**: `load-test.js`
- **Features**:
  - Multi-stage load simulation
  - Performance thresholds
  - Error rate monitoring
  - Realistic game scenarios

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Browser                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Game UI       │  │   Statistics    │  │   Dark/Light    │ │
│  │   (HTML/CSS/JS) │  │   Panel         │  │   Mode Toggle   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTP/HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Load Balancer                           │ │
│  │              (k8s Service - LoadBalancer)                  │ │
│  └─────────────────────────────┬───────────────────────────────┘ │
│                                │
│                                ▼
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Horizontal Pod Autoscaler (HPA)               │ │
│  │              CPU: 70% | Memory: 80%                        │ │
│  └─────────────────────────────┬───────────────────────────────┘ │
│                                │
│                                ▼
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Application Pods                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │ │
│  │  │   Pod 1     │  │   Pod 2     │  │   Pod N     │        │ │
│  │  │ (Container) │  │ (Container) │  │ (Container) │        │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │ │
│  └─────────────────────────────┬───────────────────────────────┘ │
│                                │
│                                ▼
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                Persistent Volume (PVC)                     │ │
│  │                    SQLite Database                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Test      │  │   Build     │  │   Deploy    │            │
│  │   (Jest)    │  │   (Docker)  │  │   (k8s)     │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                │
│                                ▼
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Load Testing (k6)                       │ │
│  │              Performance & Scaling Validation               │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Game Creation**: Client → API → Database
2. **Move Processing**: Client → API → Game Logic → Database → Client
3. **Statistics**: Client → API → Database → Client
4. **Auto-scaling**: Metrics Server → HPA → Kubernetes → Pod Scaling

## Security Features

- **Helmet.js**: Security headers
- **CORS**: Cross-origin resource sharing
- **Non-root container**: Docker security
- **Input validation**: API request validation
- **SQL injection prevention**: Parameterized queries

## Performance Features

- **Horizontal scaling**: Kubernetes HPA
- **Resource limits**: CPU/Memory constraints
- **Health checks**: Liveness and readiness probes
- **Load balancing**: Kubernetes service
- **Database optimization**: SQLite with proper indexing

## Monitoring & Observability

- **Health endpoints**: `/health`
- **Request logging**: Morgan middleware
- **Load testing**: k6 performance metrics
- **Kubernetes metrics**: Resource utilization
- **Error tracking**: Comprehensive error handling
