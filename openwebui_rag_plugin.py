from typing import Any, Dict

import requests


class RAGPlugin:
    def __init__(self, api_url: str = "http://localhost:8000"):
        self.api_url = api_url

    def query_rag(self, question: str) -> Dict[str, Any]:
        """Query the RAG system via API"""
        try:
            response = requests.post(
                f"{self.api_url}/query",
                json={"question": question},
                headers={"Content-Type": "application/json"},
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e)}

    def is_board_game_question(self, question: str) -> bool:
        """Check if question is about supported board games"""
        keywords = [
            "monopoly",
            "property",
            "boardwalk",
            "jail",
            "chance",
            "community chest",
            "ticket to ride",
            "train",
            "route",
            "destination",
            "railroad",
        ]
        return any(keyword in question.lower() for keyword in keywords)

    def process_message(self, message: str) -> str:
        """Process user message and return RAG-enhanced response"""
        if self.is_board_game_question(message):
            result = self.query_rag(message)
            if "error" not in result:
                answer = result["answer"]
                sources = result["sources"]

                # Format response with sources
                response = f"{answer}\n\n**Sources:**\n"
                for source in sources[:3]:  # Show top 3 sources
                    response += f"• {source['source']} (page {source['page']})\n"

                return response
            else:
                return f"I encountered an error accessing the game database: {result['error']}"
        else:
            return "I can help with questions about Monopoly and Ticket to Ride. For other topics, I'll respond as a general AI assistant."


# Usage example for OpenWebUI integration
if __name__ == "__main__":
    plugin = RAGPlugin()

    # Test the plugin
    test_questions = [
        "How do you get out of jail in Monopoly?",
        "What's the weather like today?",
        "How do you win Ticket to Ride?",
    ]

    for question in test_questions:
        print(f"Q: {question}")
        print(f"A: {plugin.process_message(question)}")
        print("-" * 50)
