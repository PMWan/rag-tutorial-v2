# Board Games RAG API

A FastAPI-based REST API that wraps the RAG (Retrieval-Augmented Generation) system for querying board game rules.

## Setup

1. **Install dependencies:**

   ```bash
   uv sync
   ```

2. **Populate the database:**

   ```bash
   uv run python populate_database.py
   ```

3. **Start the API server:**

   ```bash
   uv run python api.py
   ```

The API will be available at `http://localhost:8000`

## API Endpoints

### GET `/`

Root endpoint with API information.

**Response:**

```json
{
  "message": "Board Games RAG API",
  "version": "1.0.0",
  "endpoints": {
    "POST /query": "Ask a question about board games",
    "GET /health": "Check API and database health",
    "GET /docs": "API documentation"
  }
}
```

### GET `/health`

Check if the API and database are healthy.

**Response:**

```json
{
  "status": "healthy",
  "database_loaded": true,
  "message": "API is running and database is loaded"
}
```

### POST `/query`

Query the RAG system with a question about board games.

**Request:**

```json
{
  "question": "How do you win in Monopoly?"
}
```

**Response:**

```json
{
  "answer": "To win in Monopoly, you need to be the last player remaining with money...",
  "sources": [
    {
      "id": "monopoly_rule_1",
      "content": "The goal of Monopoly is to become the wealthiest player...",
      "score": 0.85
    }
  ],
  "question": "How do you win in Monopoly?"
}
```

### GET `/games`

Get list of supported board games.

**Response:**

```json
{
  "games": [
    {
      "name": "Monopoly",
      "description": "Classic property trading board game",
      "keywords": ["monopoly", "property", "boardwalk", "jail", "chance", "community chest"]
    },
    {
      "name": "Ticket to Ride",
      "description": "Train route building game",
      "keywords": ["ticket to ride", "train", "route", "destination", "railroad"]
    }
  ]
}
```

## Interactive Documentation

Once the server is running, you can access:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## Testing

Run the test script to verify the API is working:

```bash
uv run python test_api.py
```

## Example Usage

### Using curl

```bash
# Check health
curl http://localhost:8000/health

# Ask a question
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What happens when you land on Free Parking?"}'
```

### Using Python requests

```python
import requests

# Ask a question
response = requests.post(
    "http://localhost:8000/query",
    json={"question": "How do you collect rent in Monopoly?"}
)

if response.status_code == 200:
    data = response.json()
    print(f"Answer: {data['answer']}")
    print(f"Sources: {len(data['sources'])} found")
else:
    print(f"Error: {response.text}")
```

## Architecture

The API consists of:

1. **`api.py`** - FastAPI application with endpoints
2. **`query_data_enhanced.py`** - Enhanced RAG functionality with structured responses
3. **`test_api.py`** - Test script for API endpoints

The API wraps the existing RAG system and provides:

- RESTful endpoints for querying
- Structured JSON responses
- Health monitoring
- CORS support for web applications
- Interactive API documentation

## Production Considerations

For production deployment:

1. **Security**: Configure CORS origins appropriately
2. **Rate limiting**: Add rate limiting middleware
3. **Authentication**: Add authentication if needed
4. **Logging**: Add proper logging
5. **Monitoring**: Add health checks and metrics
6. **Environment variables**: Use environment variables for configuration
