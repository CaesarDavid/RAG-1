# LocalRAG

A Phoenix LiveView application that lets a local business drag-and-drop any documents (PDF, TXT, Markdown, CSV, JSON) and instantly chat with that knowledge using Retrieval-Augmented Generation.

**Stack:**

- **Elixir / Phoenix LiveView** – realtime UI with drag-and-drop upload
- **BAAI/bge-m3** via Ollama – 1024-dim multilingual embeddings
- **PostgreSQL + pgvector** – vector storage & cosine-similarity search
- **Ollama** – local LLM for answer generation (default: `llama3.2`)

---

## Prerequisites

| Tool                | Install                      |
| ------------------- | ---------------------------- |
| Elixir 1.15+        | `brew install elixir`        |
| PostgreSQL 15+      | `brew install postgresql@15` |
| pgvector extension  | `brew install pgvector`      |
| Ollama              | https://ollama.com           |
| pdftotext (for PDF) | `brew install poppler`       |

---

## 1. Pull models into Ollama

```bash
ollama pull bge-m3        # embedding model (~600 MB)
ollama pull llama3.2      # generation model (~2 GB)
```

> To use a different generation model, change `generation_model` in `config/config.exs`.

---

## 2. Create the database and run migrations

```bash
mix ecto.create
mix ecto.migrate
```

The migrations will:

1. Enable the `vector` extension in Postgres
2. Create the `documents` table
3. Create the `chunks` table with a `vector(1024)` column and an IVFFlat index

---

## 3. Start the server

```bash
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

---

## Usage

### Upload documents

1. Go to `/` (Knowledge Base page)
2. Drag & drop files onto the upload zone (or click "Select files")
3. Click **Upload & Vectorize** — processing happens in the background
4. Watch the status column update: `Pending → Processing → Ready`

### Chat

1. Click **Chat** (top-right) or go to `/chat`
2. Ask any question in natural language
3. The system embeds your question, retrieves the most relevant chunks, and generates an answer
4. Expand **Sources** below any answer to see exactly which document chunks were used

---

## Configuration (`config/config.exs`)

```elixir
config :local_rag, :rag,
  ollama_url: "http://localhost:11434",  # Ollama base URL
  embedding_model: "bge-m3",             # must be pulled in Ollama
  generation_model: "llama3.2",          # must be pulled in Ollama
  embedding_dimensions: 1024,            # bge-m3 output size
  chunk_size: 500,                       # characters per chunk
  chunk_overlap: 50,                     # overlap between chunks
  top_k: 5                               # retrieved chunks per query
```

---

## Project structure

```
lib/
  local_rag/
    documents/document.ex   – Ecto schema
    chunks/chunk.ex         – Ecto schema with Pgvector type
    documents.ex            – documents context
    chunks.ex               – chunks context + similarity search
    embeddings.ex           – Ollama bge-m3 client
    extractor.ex            – PDF/TXT/CSV/JSON text extraction
    chunker.ex              – sliding-window text chunker
    processor.ex            – async ingest pipeline (extract→chunk→embed→store)
    rag.ex                  – RAG query (embed→retrieve→generate)
  local_rag_web/
    live/upload_live.ex     – drag-and-drop upload LiveView
    live/chat_live.ex       – chat LiveView
```
