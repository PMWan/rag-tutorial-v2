#!/usr/bin/env python3
"""
Test script for the Board Games RAG API
Run this after starting the API server with: uv run python api.py
"""

import json

import requests

# API base URL
BASE_URL = "http://localhost:8000"


def test_health():
    """Test the health endpoint"""
    print("🔍 Testing health endpoint...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print()


def test_games():
    """Test the games endpoint"""
    print("🎲 Testing games endpoint...")
    response = requests.get(f"{BASE_URL}/games")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print()


def test_query(question: str):
    """Test the query endpoint"""
    print(f"❓ Testing query: {question}")

    payload = {"question": question}
    response = requests.post(f"{BASE_URL}/query", json=payload)

    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Answer: {data['answer']}")
        print(f"Sources: {len(data['sources'])} found")
        for i, source in enumerate(data["sources"], 1):
            print(f"  {i}. {source['id']} (score: {source['score']:.3f})")
    else:
        print(f"Error: {response.text}")
    print()


def main():
    """Run all tests"""
    print("🚀 Board Games RAG API Test Suite")
    print("=" * 50)

    # Test basic endpoints
    test_health()
    test_games()

    # Test queries
    test_queries = [
        "How do you win in Monopoly?",
        "What happens when you land on Free Parking?",
        "How do you collect rent in Monopoly?",
        "What are the basic rules of Ticket to Ride?",
        "How do you score points in Ticket to Ride?",
    ]

    for query in test_queries:
        test_query(query)


if __name__ == "__main__":
    main()
