import os

import streamlit as st

from query_data import query_rag

# Page config
st.set_page_config(page_title="RAG Chat - Board Games", page_icon="🎲", layout="wide")

# Title and description
st.title("🎲 Board Games RAG Chat")
st.markdown("Ask questions about Monopoly and Ticket to Ride rules!")

# Check if database exists
if not os.path.exists("chroma"):
    st.error(
        "⚠️ Database not found! Please run `uv run python populate_database.py` first."
    )
    st.stop()

# Initialize chat history
if "messages" not in st.session_state:
    st.session_state.messages = []

# Display chat history
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if "sources" in message:
            with st.expander("📚 Sources"):
                for source in message["sources"]:
                    st.text(f"• {source}")

# Chat input
if prompt := st.chat_input("Ask a question about the board games..."):
    # Add user message to chat history
    st.session_state.messages.append({"role": "user", "content": prompt})

    # Display user message
    with st.chat_message("user"):
        st.markdown(prompt)

    # Display assistant response
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            try:
                # Get response from RAG system
                response = query_rag(prompt)

                # Parse response to extract sources
                if "Sources:" in response:
                    response_text, sources_text = response.split("Sources:", 1)
                    sources = [
                        s.strip()
                        for s in sources_text.strip("[]").split(",")
                        if s.strip()
                    ]
                else:
                    response_text = response
                    sources = []

                # Display response
                st.markdown(response_text)

                # Display sources if available
                if sources:
                    with st.expander("📚 Sources"):
                        for source in sources:
                            st.text(f"• {source}")

                # Add assistant message to chat history
                st.session_state.messages.append(
                    {"role": "assistant", "content": response_text, "sources": sources}
                )

            except Exception as e:
                st.error(f"Error: {str(e)}")
                st.session_state.messages.append(
                    {
                        "role": "assistant",
                        "content": f"Sorry, I encountered an error: {str(e)}",
                    }
                )

# Sidebar with info
with st.sidebar:
    st.header("ℹ️ About")
    st.markdown(
        """
    This RAG system can answer questions about:
    - **Monopoly** rules and gameplay
    - **Ticket to Ride** instructions
    
    The system searches through PDF documents and provides answers with source references.
    """
    )

    st.header("🔧 Database Info")
    if os.path.exists("chroma"):
        st.success("✅ Database loaded")
        # Count documents (simple check)
        try:
            from query_data import query_rag

            st.info("Database is ready for queries")
        except:
            st.warning("Database exists but may need to be rebuilt")
    else:
        st.error("❌ Database not found")

    st.header("🚀 Quick Actions")
    if st.button("Clear Chat History"):
        st.session_state.messages = []
        st.rerun()

    if st.button("Rebuild Database"):
        st.info("Run this command in terminal:")
        st.code("uv run python populate_database.py --reset")
