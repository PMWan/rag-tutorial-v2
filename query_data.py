import argparse

from langchain.prompts import ChatPromptTemplate
from langchain_chroma import Chroma
from langchain_ollama import OllamaLLM

from get_embedding_function import get_embedding_function

CHROMA_PATH = "chroma"

PROMPT_TEMPLATE = """
Answer the question based ONLY on the following context. If the context doesn't contain enough information to answer the question, say so clearly.

Context:
{context}

---

Question: {question}

Instructions:
- Answer based ONLY on the provided context
- If the context doesn't contain the answer, say "The provided context doesn't contain enough information to answer this question"
- Do not use any external knowledge
- Be specific and accurate
"""


def main():
    # Create CLI.
    parser = argparse.ArgumentParser()
    parser.add_argument("query_text", type=str, help="The query text.")
    args = parser.parse_args()
    query_text = args.query_text
    query_rag(query_text)


def query_rag(query_text: str):
    # Prepare the DB.
    embedding_function = get_embedding_function()
    db = Chroma(persist_directory=CHROMA_PATH, embedding_function=embedding_function)

    # Search the DB.
    results = db.similarity_search_with_score(
        query_text, k=8
    )  # Get more results for filtering

    # Filter results by relevance and source
    filtered_results = filter_results_by_relevance(query_text, results)

    # Limit to top 5 after filtering
    filtered_results = filtered_results[:5]

    context_text = "\n\n---\n\n".join(
        [doc.page_content for doc, _score in filtered_results]
    )
    prompt_template = ChatPromptTemplate.from_template(PROMPT_TEMPLATE)
    prompt = prompt_template.format(context=context_text, question=query_text)
    # print(prompt)

    model = OllamaLLM(model="llama3.2")
    response_text = model.invoke(prompt)

    sources = [doc.metadata.get("id", None) for doc, _score in filtered_results]
    formatted_response = f"Response: {response_text}\nSources: {sources}"
    print(formatted_response)
    return response_text


def filter_results_by_relevance(query_text: str, results):
    """Filter results to prioritize relevant sources and avoid cross-contamination."""
    query_lower = query_text.lower()

    # Keywords that indicate which game the question is about
    monopoly_keywords = [
        "monopoly",
        "property",
        "boardwalk",
        "park place",
        "jail",
        "go to jail",
        "free parking",
        "chance",
        "community chest",
    ]
    ticket_ride_keywords = [
        "ticket to ride",
        "ticket",
        "train",
        "route",
        "destination",
        "railroad",
        "tracks",
    ]

    # Determine which game the question is about
    is_monopoly_question = any(keyword in query_lower for keyword in monopoly_keywords)
    is_ticket_ride_question = any(
        keyword in query_lower for keyword in ticket_ride_keywords
    )

    # If we can determine the game, filter by source
    if is_monopoly_question or is_ticket_ride_question:
        filtered_results = []
        for doc, score in results:
            source = doc.metadata.get("source", "")
            source_lower = source.lower()

            # Prioritize the correct game's documents
            if is_monopoly_question and "monopoly" in source_lower:
                filtered_results.append((doc, score))
            elif is_ticket_ride_question and "ticket_to_ride" in source_lower:
                filtered_results.append((doc, score))

        # If we found relevant documents, return them; otherwise return original results
        if filtered_results:
            return filtered_results

    # If we can't determine the game or no filtered results, return original results
    return results


if __name__ == "__main__":
    main()
