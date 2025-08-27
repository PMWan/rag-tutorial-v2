# Database Setup: RDS and ElastiCache

## RDS (Relational Database Service)

### What is RDS?

AWS's managed relational database service that handles:

- Database administration
- Patching and updates
- Backups and recovery
- High availability
- Scaling

### Why use RDS in RAG system?

1. **User Management**: Store user accounts, subscriptions, billing
2. **Query History**: Track what questions users ask
3. **Usage Analytics**: Monitor API usage and performance
4. **Document Metadata**: Store information about uploaded documents
5. **Billing Data**: Track usage for monetization

### RDS Setup for RAG

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    api_key VARCHAR(255) UNIQUE NOT NULL,
    subscription_tier VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT NOW(),
    last_active TIMESTAMP
);

-- Query history
CREATE TABLE query_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sources JSONB,
    response_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Document metadata
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    filename VARCHAR(255) NOT NULL,
    file_size BIGINT,
    document_type VARCHAR(50),
    upload_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'processing'
);

-- API usage tracking
CREATE TABLE api_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    endpoint VARCHAR(100),
    response_time_ms INTEGER,
    status_code INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## ElastiCache (Redis)

### What is ElastiCache?

AWS's managed in-memory data store service:

- **Redis**: In-memory key-value store
- **Memcached**: Simple object caching system

### Why use ElastiCache in RAG system?

1. **Response Caching**: Cache common questions and answers
2. **Session Management**: Store user sessions and preferences
3. **Rate Limiting**: Track API usage per user
4. **Vector Cache**: Cache frequently accessed embeddings
5. **Queue Management**: Handle background processing tasks

### Redis Setup for RAG

```python
# Example Redis usage in RAG system
import redis
import json

# Connect to Redis
redis_client = redis.Redis(
    host='your-elasticache-endpoint',
    port=6379,
    decode_responses=True
)

# Cache responses
def cache_response(question, answer, sources, ttl=3600):
    key = f"rag:response:{hash(question)}"
    data = {
        'answer': answer,
        'sources': sources,
        'timestamp': time.time()
    }
    redis_client.setex(key, ttl, json.dumps(data))

# Get cached response
def get_cached_response(question):
    key = f"rag:response:{hash(question)}"
    cached = redis_client.get(key)
    if cached:
        return json.loads(cached)
    return None

# Rate limiting
def check_rate_limit(user_id, limit=100, window=3600):
    key = f"rate_limit:{user_id}:{int(time.time() // window)}"
    current = redis_client.incr(key)
    if current == 1:
        redis_client.expire(key, window)
    return current <= limit

# Session management
def store_session(user_id, session_data, ttl=86400):
    key = f"session:{user_id}"
    redis_client.setex(key, ttl, json.dumps(session_data))
```

## Cost Comparison

| Service | Purpose | Monthly Cost | Benefits |
|---------|---------|-------------|----------|
| **RDS PostgreSQL** | User data, analytics | $50-200 | ACID compliance, complex queries |
| **ElastiCache Redis** | Caching, sessions | $30-100 | Fast access, simple data |
| **ChromaDB (Vector)** | Embeddings storage | $0 (self-hosted) | Vector similarity search |

## Setup Commands

### Create RDS Instance

```bash
aws rds create-db-instance \
  --db-instance-identifier rag-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username raguser \
  --master-user-password secure_password \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --db-subnet-group-name rag-subnet-group
```

### Create ElastiCache Cluster

```bash
aws elasticache create-cache-cluster \
  --cache-cluster-id rag-redis \
  --cache-node-type cache.t3.micro \
  --engine redis \
  --num-cache-nodes 1 \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --subnet-group-name rag-subnet-group
```

## Integration with RAG API

Update your `api.py` to use these services:

```python
import psycopg2
import redis
from datetime import datetime

# Database connections
db_conn = psycopg2.connect(
    host=os.getenv('RDS_ENDPOINT'),
    database='ragdb',
    user='raguser',
    password=os.getenv('DB_PASSWORD')
)

redis_client = redis.Redis(
    host=os.getenv('REDIS_ENDPOINT'),
    port=6379,
    decode_responses=True
)

@app.post("/query")
async def query_with_tracking(request: QueryRequest, user_id: int = None):
    # Check rate limit
    if not check_rate_limit(user_id):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    
    # Check cache first
    cached = get_cached_response(request.question)
    if cached:
        return cached
    
    # Process query
    start_time = time.time()
    result = query_rag_structured(request.question)
    response_time = int((time.time() - start_time) * 1000)
    
    # Cache response
    cache_response(request.question, result['answer'], result['sources'])
    
    # Log usage
    if user_id:
        log_query(user_id, request.question, result['answer'], response_time)
    
    return result
```


