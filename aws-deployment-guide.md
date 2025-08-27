# AWS Deployment Guide for Ollama RAG System

## Option 1: EC2 with GPU (Recommended)

### Instance Types

- **g4dn.xlarge**: 1 GPU, 4 vCPU, 16GB RAM - Good for testing
- **g5.xlarge**: 1 GPU, 4 vCPU, 16GB RAM - Better performance
- **g5.2xlarge**: 1 GPU, 8 vCPU, 32GB RAM - Production ready

### Setup Steps

1. **Launch EC2 Instance:**

```bash
# Use Ubuntu 22.04 LTS AMI
# Enable GPU support
# Attach EBS volume (at least 50GB)
```

2. **Install Ollama:**

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

3. **Deploy Your RAG System:**

```bash
# Clone your repo
git clone <your-repo>
cd rag-tutorial-v2

# Install dependencies
curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync

# Populate database
uv run python populate_database.py

# Create custom model
ollama create rag-boardgames -f rag-modelfile

# Start API
uv run python api.py
```

4. **Setup Reverse Proxy (Nginx):**

```bash
sudo apt install nginx
sudo nano /etc/nginx/sites-available/rag-api
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Option 2: ECS with Fargate (Serverless)

### Benefits

- No server management
- Auto-scaling
- Pay per use

### Dockerfile

```dockerfile
FROM ubuntu:22.04

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Install Python and dependencies
RUN apt update && apt install -y python3 python3-pip
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Copy application
COPY . /app
WORKDIR /app

# Install dependencies
RUN uv sync

# Populate database
RUN uv run python populate_database.py

# Create custom model
RUN ollama create rag-boardgames -f rag-modelfile

# Expose ports
EXPOSE 8000

# Start application
CMD ["uv", "run", "python", "api.py"]
```

## Option 3: SageMaker (Enterprise)

### Benefits

- Managed ML infrastructure
- Built-in monitoring
- Enterprise features

### Setup

1. Create SageMaker notebook instance
2. Deploy as SageMaker endpoint
3. Use SageMaker inference containers

## Cost Comparison

| Option | Monthly Cost | Pros | Cons |
|--------|-------------|------|------|
| EC2 g5.xlarge | ~$500-800 | Full control, cost-effective | Manual management |
| ECS Fargate | ~$300-600 | Serverless, auto-scaling | Limited GPU options |
| SageMaker | ~$1000+ | Enterprise features | Expensive, complex |

## Recommended Architecture

```
Internet → CloudFront → ALB → EC2 (Ollama + RAG API)
                    ↓
                RDS/ElastiCache (optional)
```

## Security Considerations

1. **VPC Configuration:**
   - Private subnets for Ollama instances
   - Public subnets for load balancers
   - Security groups limiting access

2. **Authentication:**
   - API Gateway with API keys
   - Cognito for user management
   - IAM roles for service permissions

3. **Monitoring:**
   - CloudWatch for metrics
   - X-Ray for tracing
   - CloudTrail for audit logs

## Auto-scaling Setup

```yaml
# Auto Scaling Group
Min: 1
Max: 5
Target CPU: 70%

# Scale up when:
- CPU > 70% for 5 minutes
- Memory > 80% for 5 minutes

# Scale down when:
- CPU < 30% for 10 minutes
```

## Production Checklist

- [ ] SSL/TLS certificates
- [ ] Load balancer health checks
- [ ] Database backups
- [ ] Log aggregation
- [ ] Monitoring alerts
- [ ] Disaster recovery plan
- [ ] Cost optimization
- [ ] Security hardening
