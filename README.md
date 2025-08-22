# rag-tutorial-v2

A RAG (Retrieval-Augmented Generation) tutorial project using vector storage and document processing.

## Setup

This project uses [uv](https://github.com/astral-sh/uv) for dependency management.

### Prerequisites

- Python 3.8+
- uv (install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`)

### Installation

```bash
# Install dependencies
uv sync

# Or install individually
uv add pypdf langchain chromadb boto3
uv add --dev pytest
```

### Running the project

```bash
# Run Python scripts with uv
uv run python populate_database.py
uv run python query_data.py
uv run python test_rag.py

# Or activate the virtual environment
source .venv/bin/activate
python populate_database.py
```

## Dependencies

- **pypdf**: PDF processing
- **langchain**: RAG framework
- **chromadb**: Vector database
- **boto3**: AWS SDK
- **pytest**: Testing framework (dev dependency)
