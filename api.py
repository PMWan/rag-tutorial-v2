import logging
import os
from datetime import datetime
from typing import List

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from query_data_enhanced import query_rag_structured

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Board Games RAG API",
    description="API for querying board game rules using RAG (Retrieval-Augmented Generation)",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request tracking
request_count = 0
start_time = datetime.now()


# Pydantic models for request/response
class QueryRequest(BaseModel):
    question: str


class Source(BaseModel):
    id: str
    content: str
    score: float


class QueryResponse(BaseModel):
    answer: str
    sources: List[Source]
    question: str


class HealthResponse(BaseModel):
    status: str
    database_loaded: bool
    message: str


@app.get("/", response_model=dict)
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Board Games RAG API",
        "version": "1.0.0",
        "endpoints": {
            "POST /query": "Ask a question about board games",
            "GET /health": "Check API and database health",
            "GET /docs": "API documentation",
        },
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Check if the API and database are healthy"""
    database_exists = os.path.exists("chroma")

    if database_exists:
        return HealthResponse(
            status="healthy",
            database_loaded=True,
            message="API is running and database is loaded",
        )
    else:
        return HealthResponse(
            status="unhealthy",
            database_loaded=False,
            message="Database not found. Please run populate_database.py first.",
        )


@app.post("/query", response_model=QueryResponse)
async def query_board_games(request: QueryRequest):
    """Query the RAG system with a question about board games"""

    # Check if database exists
    if not os.path.exists("chroma"):
        raise HTTPException(
            status_code=503,
            detail="Database not found. Please run populate_database.py first.",
        )

    try:
        # Get structured response from the RAG system
        result = query_rag_structured(request.question)
        answer = result["answer"]
        sources = [
            Source(id=source["id"], content=source["content"], score=source["score"])
            for source in result["sources"]
        ]

        return QueryResponse(answer=answer, sources=sources, question=request.question)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing query: {str(e)}")


@app.get("/games")
async def get_supported_games():
    """Get list of supported board games"""
    return {
        "games": [
            {
                "name": "Monopoly",
                "description": "Classic property trading board game",
                "keywords": [
                    "monopoly",
                    "property",
                    "boardwalk",
                    "jail",
                    "chance",
                    "community chest",
                ],
            },
            {
                "name": "Ticket to Ride",
                "description": "Train route building game",
                "keywords": [
                    "ticket to ride",
                    "train",
                    "route",
                    "destination",
                    "railroad",
                ],
            },
        ]
    }


@app.get("/stats")
async def get_server_stats():
    """Get server statistics and monitoring info"""
    uptime = datetime.now() - start_time
    return {
        "uptime_seconds": uptime.total_seconds(),
        "uptime_formatted": str(uptime).split(".")[0],  # Remove microseconds
        "total_requests": request_count,
        "server_start_time": start_time.isoformat(),
        "current_time": datetime.now().isoformat(),
    }


@app.get("/logs")
async def get_recent_logs():
    """Get recent server logs (last 50 lines)"""
    try:
        # This is a simple implementation - in production you'd want a proper log management system
        return {
            "message": "Logs endpoint - check your terminal/console for real-time logs",
            "logging_level": "INFO",
            "note": "Use uvicorn with --log-level debug for more detailed logs",
        }
    except Exception as e:
        return {"error": f"Could not retrieve logs: {str(e)}"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
