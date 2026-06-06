# Enterprise Multi-Model AI Platform

> Production-grade LLMOps + MLOps platform — one model per pod, Kubernetes-native, enterprise-ready.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Overview](#architecture-overview)
3. [Technology Stack](#technology-stack)
4. [Repository Structure](#repository-structure)
5. [Core Modules](#core-modules)
   - [Chat Module](#1-chat-module)
   - [Model Management Module](#2-model-management-module)
   - [Dataset Management Module](#3-dataset-management-module)
   - [Training Module](#4-training-module)
   - [Adapter Management Module](#5-adapter-management-module)
   - [Evaluation Module](#6-evaluation-module)
   - [Tool Calling Module](#7-tool-calling-module)
   - [RAG Module](#8-rag-module)
6. [One Model One Pod Architecture](#one-model-one-pod-architecture)
   - [Pod Isolation Design](#pod-isolation-design)
   - [Kubernetes Manifests](#kubernetes-manifests)
   - [Helm Charts](#helm-charts)
   - [Health Probes](#health-probes)
   - [Resource Requests Per Model](#resource-requests-per-model)
   - [HPA Configuration](#hpa-configuration)
   - [PVC for Model Weights](#pvc-for-model-weights)
   - [Node Affinity](#node-affinity)
7. [Frontend Architecture](#frontend-architecture)
8. [Backend Architecture](#backend-architecture)
9. [Database Design](#database-design)
10. [Model Serving Architecture](#model-serving-architecture)
11. [Training Pipeline](#training-pipeline)
12. [Monitoring & Observability](#monitoring--observability)
13. [CI/CD Pipeline](#cicd-pipeline)
14. [Security](#security)
15. [API Reference](#api-reference)
16. [Environment Variables](#environment-variables)
17. [Local Development Setup](#local-development-setup)
18. [Deployment Guide](#deployment-guide)
19. [Future Enhancements](#future-enhancements)

---

## Project Overview

The Enterprise Multi-Model AI Platform is a production-grade AI ecosystem that enables organizations to:

- Chat with multiple Small Language Models (SLMs) and Large Language Models (LLMs) simultaneously
- Perform dynamic model selection based on task type, cost, and latency
- Execute tool calling and function calling workflows
- Perform Retrieval-Augmented Generation (RAG)
- Upload and manage datasets
- Train and fine-tune domain-specific models using LoRA and QLoRA
- Evaluate model performance with standard benchmarks
- Deploy trained adapters into production
- Monitor model health, GPU utilization, and platform usage in real time

The platform provides a ChatGPT-like user experience while also offering full MLOps and LLMOps capabilities for model management, training, deployment, and monitoring.

---

## Architecture Overview

```
+------------------------------------------------------------------+
|                         Kubernetes Cluster                       |
|                                                                  |
|  +-----------+    +-------------+    +----------------------+    |
|  | Frontend  |--->|  API Gateway |--->|      Chat API        |    |
|  |  (React)  |    |  (Ingress)  |    |  (FastAPI Router)    |    |
|  +-----------+    +-------------+    +-----------+----------+    |
|                                                  |               |
|                          Model Router (per req)  |               |
|                          +------------------------+               |
|                          |                                        |
|  +----------------------------------------------------------+    |
|  |              Model Pods (1 model = 1 pod)                |    |
|  |                                                          |    |
|  | +----------+ +----------+ +----------+ +----------+     |    |
|  | |  Llama   | | Mistral  | |   Qwen   | | DeepSeek |     |    |
|  | | 3.1 8B   | |   7B     | |  2.5 7B  | |   7B     |     |    |
|  | | 2x GPU   | | 1x GPU   | | 1x GPU   | | 2x GPU   |     |    |
|  | +----+-----+ +----+-----+ +----+-----+ +----+-----+     |    |
|  |      |            |            |            |            |    |
|  | +----+-----+ +----+-----+ +---+------+ +---+------+     |    |
|  | |pvc/llama | |pvc/mistr | |pvc/qwen  | |pvc/deep  |     |    |
|  | | weights  | | weights  | | weights  | | weights  |     |    |
|  | +----------+ +----------+ +----------+ +----------+     |    |
|  +----------------------------------------------------------+    |
|                                                                  |
|  +----------+ +----------+ +----------+ +-----------------+     |
|  |PostgreSQL| |  Redis   | |  Qdrant  | | Prometheus      |     |
|  |          | |          | | (Vectors)| | + Grafana + Loki|     |
|  +----------+ +----------+ +----------+ +-----------------+     |
+------------------------------------------------------------------+
```

---

## Technology Stack

### Frontend

| Layer | Technology |
|---|---|
| Framework | React 18 + TypeScript |
| UI Library | Material UI v5 or Ant Design v5 |
| State Management | Zustand |
| Data Fetching | React Query (TanStack Query) |
| Routing | React Router v6 |
| Markdown Rendering | React Markdown + remark-gfm |
| HTTP Client | Axios |
| Streaming | EventSource / SSE |
| Build Tool | Vite |

### Backend

| Layer | Technology |
|---|---|
| Framework | FastAPI (Python 3.11+) |
| AI Frameworks | Transformers, PEFT, Accelerate, BitsAndBytes, TRL |
| Model Serving | Transformers pipeline (vLLM planned) |
| Auth | JWT + OAuth2 + RBAC |
| ORM | SQLAlchemy 2.0 (async) |
| Migrations | Alembic |
| Task Queue | Celery + Redis |
| Validation | Pydantic v2 |

### Databases

| Database | Purpose |
|---|---|
| PostgreSQL 15 | Users, conversations, messages, models, training jobs, adapters, datasets |
| Redis 7 | Session cache, prompt cache, rate limiting, Celery task broker |
| Qdrant | Embeddings, knowledge base, RAG documents |

### Infrastructure

| Layer | Technology |
|---|---|
| Container Runtime | Docker |
| Orchestration | Kubernetes 1.28+ |
| Package Manager | Helm 3 |
| GPU Operator | NVIDIA GPU Operator |
| CI/CD | GitHub Actions |
| Container Registry | Docker Hub / GHCR |
| Monitoring | Prometheus + Grafana + Loki |

---

## Repository Structure

```
enterprise-ai-platform/
|
+-- frontend/
|   +-- public/
|   +-- src/
|       +-- pages/
|       |   +-- chat/
|       |   |   +-- ChatPage.tsx
|       |   |   +-- ConversationList.tsx
|       |   |   +-- MessageThread.tsx
|       |   +-- models/
|       |   |   +-- ModelsPage.tsx
|       |   |   +-- ModelCard.tsx
|       |   +-- datasets/
|       |   |   +-- DatasetsPage.tsx
|       |   |   +-- DatasetUpload.tsx
|       |   +-- training/
|       |   |   +-- TrainingPage.tsx
|       |   |   +-- TrainingJobForm.tsx
|       |   |   +-- TrainingJobList.tsx
|       |   +-- evaluation/
|       |   |   +-- EvaluationPage.tsx
|       |   +-- monitoring/
|       |   |   +-- MonitoringPage.tsx
|       |   +-- admin/
|       |       +-- AdminPage.tsx
|       +-- components/
|       |   +-- chat/
|       |   |   +-- ChatInput.tsx
|       |   |   +-- MessageBubble.tsx
|       |   |   +-- ModelSelector.tsx
|       |   +-- models/
|       |   |   +-- ModelStatusBadge.tsx
|       |   +-- training/
|       |   |   +-- TrainingProgress.tsx
|       |   +-- common/
|       |       +-- Layout.tsx
|       |       +-- Sidebar.tsx
|       |       +-- ErrorBoundary.tsx
|       +-- services/
|       |   +-- api.ts
|       |   +-- chatService.ts
|       |   +-- modelService.ts
|       |   +-- datasetService.ts
|       |   +-- trainingService.ts
|       +-- store/
|       |   +-- authStore.ts
|       |   +-- chatStore.ts
|       |   +-- modelStore.ts
|       +-- hooks/
|       |   +-- useChat.ts
|       |   +-- useStreamingResponse.ts
|       |   +-- useModels.ts
|       +-- utils/
|           +-- formatters.ts
|           +-- constants.ts
|
+-- backend/
|   +-- src/
|       +-- api/
|       |   +-- v1/
|       |   |   +-- chat.py
|       |   |   +-- models.py
|       |   |   +-- datasets.py
|       |   |   +-- training.py
|       |   |   +-- adapters.py
|       |   |   +-- evaluation.py
|       |   |   +-- auth.py
|       |   +-- router.py
|       +-- services/
|       |   +-- chat_service.py
|       |   +-- model_service.py
|       |   +-- dataset_service.py
|       |   +-- training_service.py
|       |   +-- adapter_service.py
|       |   +-- evaluation_service.py
|       +-- repositories/
|       |   +-- conversation_repo.py
|       |   +-- model_repo.py
|       |   +-- dataset_repo.py
|       |   +-- training_repo.py
|       +-- tools/
|       |   +-- web_search.py
|       |   +-- database_query.py
|       |   +-- document_search.py
|       +-- rag/
|       |   +-- embedder.py
|       |   +-- chunker.py
|       |   +-- retriever.py
|       +-- training/
|       |   +-- lora_trainer.py
|       |   +-- qlora_trainer.py
|       |   +-- trainer_utils.py
|       +-- models/
|       |   +-- db/
|       |   |   +-- user.py
|       |   |   +-- conversation.py
|       |   |   +-- message.py
|       |   |   +-- model_registry.py
|       |   |   +-- dataset.py
|       |   |   +-- training_job.py
|       |   |   +-- adapter.py
|       |   +-- schemas/
|       |       +-- chat.py
|       |       +-- model.py
|       |       +-- training.py
|       +-- db/
|       |   +-- session.py
|       |   +-- migrations/
|       +-- config/
|       |   +-- settings.py
|       +-- main.py
|
+-- model-services/
|   +-- llama/
|   |   +-- server.py
|   |   +-- Dockerfile
|   |   +-- requirements.txt
|   +-- mistral/
|   |   +-- server.py
|   |   +-- Dockerfile
|   |   +-- requirements.txt
|   +-- qwen/
|   |   +-- server.py
|   |   +-- Dockerfile
|   |   +-- requirements.txt
|   +-- deepseek/
|       +-- server.py
|       +-- Dockerfile
|       +-- requirements.txt
|
+-- helm/
|   +-- frontend/
|   +-- chat-api/
|   +-- training-api/
|   +-- llama-model/
|   +-- mistral-model/
|   +-- qwen-model/
|   +-- deepseek-model/
|   +-- postgres/
|   +-- redis/
|   +-- qdrant/
|   +-- monitoring/
|
+-- k8s/
|   +-- namespace.yaml
|   +-- models/
|   |   +-- llama-deployment.yaml
|   |   +-- llama-service.yaml
|   |   +-- llama-hpa.yaml
|   |   +-- llama-pvc.yaml
|   |   +-- mistral-deployment.yaml
|   |   +-- mistral-service.yaml
|   |   +-- qwen-deployment.yaml
|   |   +-- qwen-service.yaml
|   |   +-- deepseek-deployment.yaml
|   |   +-- deepseek-service.yaml
|   +-- infra/
|   |   +-- postgres.yaml
|   |   +-- redis.yaml
|   |   +-- qdrant.yaml
|   +-- monitoring/
|       +-- prometheus.yaml
|       +-- grafana.yaml
|       +-- loki.yaml
|
+-- .github/
|   +-- workflows/
|       +-- ci.yaml
|       +-- build-push.yaml
|       +-- helm-deploy.yaml
|
+-- docker-compose.yml
+-- docker-compose.gpu.yml
+-- README.md
```

---

## Core Modules

### 1. Chat Module

Provides a ChatGPT-style conversational experience with streaming support.

#### Features

- Multi-turn conversations with full history
- Server-Sent Events (SSE) streaming responses
- Per-request model switching
- Tool calling and function calling
- Conversation management (create, list, delete, rename)

#### Supported Models

| Model | Size | VRAM Required | Use Case |
|---|---|---|---|
| Llama 3.1 8B | 8B | ~16GB | General purpose, instruction following |
| Mistral 7B | 7B | ~14GB | Fast inference, coding, reasoning |
| Qwen 2.5 7B | 7B | ~14GB | Multilingual, math, coding |
| DeepSeek-R1 7B | 7B | ~14GB | Reasoning, analysis |
| Gemma 2 9B | 9B | ~18GB | Safety-tuned, general purpose |
| Phi-3 Mini | 3.8B | ~8GB | Edge / lightweight tasks |

#### API

```http
POST /api/v1/chat/completions
Authorization: Bearer <token>
Content-Type: application/json

{
  "model": "llama-3.1-8b",
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user",   "content": "Explain transformers in simple terms." }
  ],
  "stream": true,
  "temperature": 0.7,
  "max_tokens": 1024,
  "tools": []
}
```

Response (streaming SSE):

```
data: {"id":"chatcmpl-abc","delta":{"content":"Transformers"},"finish_reason":null}
data: {"id":"chatcmpl-abc","delta":{"content":" are"},"finish_reason":null}
...
data: [DONE]
```

#### Implementation Notes for Copilot

```python
# backend/src/api/v1/chat.py
# - Use StreamingResponse with media_type="text/event-stream"
# - Route each request to the correct model pod via HTTP to svc/<model-name>:8080
# - Maintain conversation history in PostgreSQL (conversation + message tables)
# - Apply prompt cache via Redis: key = sha256(model + messages), TTL = 300s
# - Enforce rate limiting via Redis: key = user_id, limit = 60 req/min
```

---

### 2. Model Management Module

Allows administrators to register, enable/disable, and monitor deployed models.

#### Features

- Register new models (name, version, endpoint URL, GPU count)
- Enable / disable models (soft toggle, no pod kill)
- View real-time model status (healthy / degraded / offline)
- View per-model GPU utilization via Prometheus
- Restart model pod via Kubernetes API
- Remove model from registry

#### API

```http
GET    /api/v1/models                  # List all models
POST   /api/v1/models                  # Register a model
GET    /api/v1/models/{id}             # Get model details
PATCH  /api/v1/models/{id}             # Update model (enable/disable)
DELETE /api/v1/models/{id}             # Deregister model
POST   /api/v1/models/{id}/restart     # Restart model pod
GET    /api/v1/models/{id}/metrics     # GPU + latency metrics
```

#### Model Registry Schema

```python
# backend/src/models/db/model_registry.py
class ModelRegistry(Base):
    __tablename__ = "model_registry"

    id: UUID
    name: str                  # "llama-3.1-8b"
    display_name: str          # "Llama 3.1 8B Instruct"
    version: str               # "3.1.0"
    endpoint_url: str          # "http://svc/llama-model:8080"
    gpu_count: int             # 2
    vram_gb: int               # 32
    max_context_length: int    # 8192
    is_enabled: bool           # True
    is_healthy: bool           # True (updated by health check job)
    created_at: datetime
    updated_at: datetime
```

---

### 3. Dataset Management Module

Provides complete dataset lifecycle management for training.

#### Features

- Upload datasets (JSONL, CSV, TXT, Parquet)
- Automatic format validation on upload
- Dataset versioning (v1, v2, ...)
- Dataset preview (first 20 rows)
- Statistics (row count, token count estimate, column info)
- Tag and search datasets

#### Supported Formats

| Format | Use Case | Validation |
|---|---|---|
| JSONL | Chat fine-tuning (instruction/response pairs) | Schema check per line |
| CSV | Tabular classification tasks | Header + type check |
| TXT | Raw pretraining data | Character encoding check |
| Parquet | Large-scale datasets | Schema + null check |

#### JSONL Schema (Chat Format)

```jsonl
{"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
{"messages": [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
```

#### API

```http
POST   /api/v1/datasets/upload         # Upload dataset file
GET    /api/v1/datasets                # List datasets
GET    /api/v1/datasets/{id}           # Get dataset details + stats
GET    /api/v1/datasets/{id}/preview   # Get first 20 rows
DELETE /api/v1/datasets/{id}           # Delete dataset
POST   /api/v1/datasets/{id}/validate  # Re-run validation
```

---

### 4. Training Module

Provides model fine-tuning with LoRA, QLoRA, and full fine-tuning.

#### Training Types

| Type | Description | VRAM Required | When to Use |
|---|---|---|---|
| QLoRA | 4-bit quantized LoRA | ~12GB per GPU | Low VRAM, most common |
| LoRA | 16-bit adapter training | ~24GB per GPU | Higher quality, more VRAM |
| Full Fine-Tuning | All weights updated | ~80GB+ per GPU | Maximum quality, rare |

#### Hyperparameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `epochs` | int | 3 | Number of training epochs |
| `batch_size` | int | 4 | Per-device batch size |
| `gradient_accumulation_steps` | int | 4 | Effective batch = batch x accum |
| `learning_rate` | float | 2e-4 | Peak learning rate |
| `lr_scheduler` | str | cosine | LR scheduler type |
| `warmup_ratio` | float | 0.05 | Warmup fraction of total steps |
| `lora_rank` | int | 16 | LoRA rank (r) |
| `lora_alpha` | int | 32 | LoRA alpha scaling |
| `lora_dropout` | float | 0.05 | LoRA dropout |
| `lora_target_modules` | list | ["q_proj","v_proj"] | Modules to apply LoRA |
| `max_seq_length` | int | 2048 | Max token length |
| `quantization` | str | 4bit | 4bit / 8bit / none |

#### Training Workflow

```
1. Select dataset         ->  Validate format + token count
2. Select base model      ->  Check GPU availability
3. Configure params       ->  Estimate VRAM + training time
4. Submit job             ->  Celery task queued
5. Training worker picks  ->  Load model + dataset
6. Training runs          ->  Logs streamed via WebSocket
7. Checkpoint saved       ->  Adapter saved to PVC
8. Evaluation triggered   ->  Auto-eval on held-out split
9. Adapter registered     ->  Available for deployment
```

#### API

```http
POST   /api/v1/training/jobs              # Submit training job
GET    /api/v1/training/jobs              # List all jobs
GET    /api/v1/training/jobs/{id}         # Get job details
DELETE /api/v1/training/jobs/{id}         # Cancel job
GET    /api/v1/training/jobs/{id}/logs    # Stream logs (SSE)
GET    /api/v1/training/jobs/{id}/metrics # Loss curve, eval metrics
```

#### Training Job Schema

```python
class TrainingJob(Base):
    __tablename__ = "training_jobs"

    id: UUID
    name: str
    base_model_id: UUID
    dataset_id: UUID
    training_type: str          # "lora" | "qlora" | "full"
    hyperparameters: dict       # JSON blob of all hyperparams
    status: str                 # pending | running | completed | failed | cancelled
    celery_task_id: str
    adapter_id: UUID            # Set on completion
    train_loss: float
    eval_loss: float
    started_at: datetime
    completed_at: datetime
    created_at: datetime
```

---

### 5. Adapter Management Module

Manages LoRA adapters trained from fine-tuning jobs.

#### Features

- Register adapter (name, base model, training job reference)
- Semantic versioning (v1.0.0, v1.1.0, ...)
- Deploy adapter to a running model pod (hot-swap via API)
- Rollback to previous adapter version
- A/B testing support (route % of traffic to new adapter)

#### API

```http
POST   /api/v1/adapters                    # Register adapter
GET    /api/v1/adapters                    # List adapters
GET    /api/v1/adapters/{id}               # Get adapter details
POST   /api/v1/adapters/{id}/deploy        # Deploy to model pod
POST   /api/v1/adapters/{id}/rollback      # Rollback to previous
DELETE /api/v1/adapters/{id}               # Delete adapter
```

#### Adapter Deployment Flow

```python
# POST /api/v1/adapters/{id}/deploy
# 1. Fetch adapter metadata from DB
# 2. Call model pod: POST http://svc/<model>:8080/adapter/load
#    body: { "adapter_path": "/adapters/<adapter_id>" }
# 3. Model pod loads PEFT adapter on top of base weights
# 4. Update model_registry.active_adapter_id in DB
# 5. Return deployment status
```

---

### 6. Evaluation Module

Measures model and adapter quality using standard metrics.

#### Metrics

| Metric | Description | Task Type |
|---|---|---|
| Accuracy | Exact match % | Classification |
| BLEU | N-gram precision vs reference | Translation, summarisation |
| ROUGE-1/2/L | Recall-oriented overlap | Summarisation |
| F1 Score | Harmonic mean precision/recall | Classification, NER |
| Perplexity | How well model predicts test set | Language modelling |
| Latency P50/P95/P99 | Inference time percentiles | Performance |
| Tokens/sec | Throughput | Performance |

#### API

```http
POST  /api/v1/evaluation/run              # Start evaluation job
GET   /api/v1/evaluation/results          # List all results
GET   /api/v1/evaluation/results/{id}     # Get result details
GET   /api/v1/evaluation/compare          # Compare two adapters/models
```

#### Evaluation Request

```json
{
  "model_id": "uuid-of-model",
  "adapter_id": "uuid-of-adapter",
  "dataset_id": "uuid-of-eval-dataset",
  "metrics": ["bleu", "rouge", "latency"],
  "num_samples": 500
}
```

---

### 7. Tool Calling Module

Supports OpenAI-compatible function calling for external integrations.

#### Supported Tools

| Tool | Description | Input | Output |
|---|---|---|---|
| `web_search` | Search the web via SerpAPI / Brave | `{ "query": str }` | Search results JSON |
| `database_query` | Run read-only SQL on internal DB | `{ "sql": str }` | Query results |
| `weather` | Current weather | `{ "city": str }` | Weather JSON |
| `document_search` | Semantic search on uploaded docs | `{ "query": str }` | Matching chunks |
| `internal_api` | Call registered internal APIs | `{ "url": str, "method": str, "body": dict }` | HTTP response |

#### Tool Calling Workflow

```
1. User sends message with tools list
2. Model generates tool_call response:
   { "tool_calls": [{ "name": "web_search", "arguments": { "query": "..." } }] }
3. Backend executes the tool
4. Tool result injected back as role=tool message
5. Model generates final natural language response
6. Full conversation (with tool call + result) saved to DB
```

#### Registering a Custom Tool

```python
# backend/src/tools/custom_tool.py
from tools.base import BaseTool

class MyCustomTool(BaseTool):
    name = "my_custom_tool"
    description = "Does X when given Y"
    parameters = {
        "type": "object",
        "properties": {
            "input_field": { "type": "string", "description": "..." }
        },
        "required": ["input_field"]
    }

    async def execute(self, input_field: str) -> dict:
        # implementation
        return { "result": "..." }
```

---

### 8. RAG Module

Retrieval-Augmented Generation for grounding responses in uploaded documents.

#### Components

| Component | Library | Description |
|---|---|---|
| Document loader | LangChain / custom | Load PDF, DOCX, TXT, HTML |
| Chunker | RecursiveCharacterTextSplitter | 512 tokens, 50 overlap |
| Embedder | sentence-transformers/all-MiniLM-L6-v2 | Generate dense vectors |
| Vector store | Qdrant | Store + search embeddings |
| Retriever | Cosine similarity top-k | Retrieve relevant chunks |
| Prompt augmenter | Custom | Inject chunks into system prompt |

#### RAG Flow

```
1. User uploads document (PDF, DOCX, TXT)
2. Document split into chunks (512 tokens, 50 token overlap)
3. Each chunk embedded -> 384-dim or 1536-dim vector
4. Vectors stored in Qdrant collection (per user or per knowledge base)
5. On user query:
   a. Embed query -> query vector
   b. Qdrant cosine similarity search -> top 5 chunks
   c. Chunks prepended to system prompt
   d. Model generates grounded response
6. Source citations returned alongside response
```

#### API

```http
POST   /api/v1/rag/documents/upload     # Upload document for RAG
GET    /api/v1/rag/documents            # List RAG documents
DELETE /api/v1/rag/documents/{id}       # Delete document + embeddings
POST   /api/v1/rag/search               # Manual semantic search test
```

---

## One Model One Pod Architecture

### Pod Isolation Design

Each model runs as a completely independent Kubernetes `Deployment` with its own:

- Docker image (model-specific dependencies)
- GPU resource requests and limits
- PersistentVolumeClaim for model weights
- ClusterIP Service
- HorizontalPodAutoscaler
- Health probes (startup + liveness + readiness)
- Prometheus scrape annotations

**Why one pod per model?**

| Concern | Shared Pod | One Pod Per Model |
|---|---|---|
| Crash isolation | One OOM kills all models | Isolated — other models unaffected |
| Independent scaling | Must scale all together | Each model scales on its own traffic |
| GPU allocation | Impossible to split cleanly | Each pod requests exactly what it needs |
| Deployment | Redeploy all to update one | `helm upgrade llama-model` only |
| Monitoring | Mixed metrics | Per-model dashboards |
| Startup time | One slow model blocks others | Parallel startup |

---

### Kubernetes Manifests

#### Namespace

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ai-platform
  labels:
    app.kubernetes.io/managed-by: helm
```

#### Llama 3.1 8B Deployment

```yaml
# k8s/models/llama-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-model
  namespace: ai-platform
  labels:
    app: llama-model
    model: llama-3.1-8b
    version: "3.1.0"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-model
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0         # Never take pod offline during update
      maxSurge: 1               # Bring up new pod before killing old
  template:
    metadata:
      labels:
        app: llama-model
        model: llama-3.1-8b
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8081"
        prometheus.io/path: "/metrics"
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: nvidia.com/gpu.memory
                    operator: Gt
                    values: ["38000"]
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: weights-check
          image: busybox:1.35
          command: ["sh", "-c", "ls /models/llama-3.1-8b/config.json || exit 1"]
          volumeMounts:
            - name: model-weights
              mountPath: /models
      containers:
        - name: llama-server
          image: your-registry/llama-model-server:3.1.0
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 8081
              name: metrics
          env:
            - name: MODEL_PATH
              value: "/models/llama-3.1-8b"
            - name: MAX_BATCH_SIZE
              value: "8"
            - name: MAX_SEQ_LENGTH
              value: "8192"
            - name: DTYPE
              value: "float16"
          resources:
            requests:
              memory: "24Gi"
              cpu: "4"
              nvidia.com/gpu: "2"
            limits:
              memory: "40Gi"
              cpu: "8"
              nvidia.com/gpu: "2"
          volumeMounts:
            - name: model-weights
              mountPath: /models
              readOnly: true
            - name: adapter-store
              mountPath: /adapters
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            failureThreshold: 30
            periodSeconds: 10       # 30 x 10s = 5 minutes max
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 10
            failureThreshold: 3
      volumes:
        - name: model-weights
          persistentVolumeClaim:
            claimName: llama-weights
        - name: adapter-store
          persistentVolumeClaim:
            claimName: adapter-store-llama
```

#### Mistral 7B Deployment (1 GPU)

```yaml
# k8s/models/mistral-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mistral-model
  namespace: ai-platform
  labels:
    app: mistral-model
    model: mistral-7b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mistral-model
  template:
    metadata:
      labels:
        app: mistral-model
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8081"
        prometheus.io/path: "/metrics"
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: nvidia.com/gpu.memory
                    operator: Gt
                    values: ["20000"]
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: mistral-server
          image: your-registry/mistral-model-server:0.3.0
          ports:
            - containerPort: 8080
            - containerPort: 8081
          env:
            - name: MODEL_PATH
              value: "/models/mistral-7b-instruct"
            - name: MAX_BATCH_SIZE
              value: "16"
            - name: DTYPE
              value: "float16"
          resources:
            requests:
              memory: "16Gi"
              cpu: "4"
              nvidia.com/gpu: "1"
            limits:
              memory: "24Gi"
              cpu: "8"
              nvidia.com/gpu: "1"
          volumeMounts:
            - name: model-weights
              mountPath: /models
              readOnly: true
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            failureThreshold: 24
            periodSeconds: 10     # 24 x 10s = 4 minutes
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            periodSeconds: 10
            failureThreshold: 3
      volumes:
        - name: model-weights
          persistentVolumeClaim:
            claimName: mistral-weights
```

#### ClusterIP Service (same pattern for all models)

```yaml
# k8s/models/llama-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: llama-model
  namespace: ai-platform
  labels:
    app: llama-model
spec:
  selector:
    app: llama-model
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      protocol: TCP
    - name: metrics
      port: 8081
      targetPort: 8081
      protocol: TCP
  type: ClusterIP
```

---

### Helm Charts

#### Helm Chart Structure (per model)

```
helm/llama-model/
+-- Chart.yaml
+-- values.yaml
+-- templates/
    +-- deployment.yaml
    +-- service.yaml
    +-- hpa.yaml
    +-- pvc.yaml
    +-- configmap.yaml
    +-- secret.yaml
```

#### Chart.yaml

```yaml
# helm/llama-model/Chart.yaml
apiVersion: v2
name: llama-model
description: Llama 3.1 8B model server — one pod deployment
type: application
version: 1.0.0
appVersion: "3.1.0"
```

#### values.yaml

```yaml
# helm/llama-model/values.yaml
replicaCount: 1

image:
  repository: your-registry/llama-model-server
  tag: "3.1.0"
  pullPolicy: IfNotPresent

model:
  name: llama-3.1-8b
  path: /models/llama-3.1-8b
  maxBatchSize: 8
  maxSeqLength: 8192
  dtype: float16

resources:
  requests:
    memory: "24Gi"
    cpu: "4"
    nvidia.com/gpu: "2"
  limits:
    memory: "40Gi"
    cpu: "8"
    nvidia.com/gpu: "2"

nodeAffinity:
  gpuMemoryMinGB: 38000

pvc:
  weightsClaimName: llama-weights
  weightsStorageClass: fast-nvme
  weightsSize: 30Gi

probes:
  startup:
    failureThreshold: 30
    periodSeconds: 10
  liveness:
    periodSeconds: 30
    failureThreshold: 3
  readiness:
    periodSeconds: 10
    failureThreshold: 3

hpa:
  minReplicas: 1
  maxReplicas: 4
  targetCPUUtilizationPercentage: 60
  customMetric:
    name: inference_queue_depth
    target: 5

service:
  type: ClusterIP
  httpPort: 8080
  metricsPort: 8081

prometheus:
  scrape: true
  path: /metrics
```

---

### Health Probes

#### Model Server Health Endpoints

```python
# model-services/llama/server.py
from fastapi import FastAPI, Response
import torch

app = FastAPI()
model = None
model_loaded = False

@app.on_event("startup")
async def load_model():
    global model, model_loaded
    model = load_model_from_path(MODEL_PATH)
    model_loaded = True

@app.get("/health")
async def liveness():
    """
    Liveness: am I alive?
    Returns 503 if model crashed or OOM.
    """
    if model is None and model_loaded:
        return Response(status_code=503)
    return {"status": "alive"}

@app.get("/ready")
async def readiness():
    """
    Readiness: am I ready to serve traffic?
    Returns 200 only after model fully loaded and warm.
    """
    if not model_loaded:
        return Response(status_code=503, content="Model still loading")
    if not torch.cuda.is_available():
        return Response(status_code=503, content="GPU unavailable")
    return {"status": "ready", "model": MODEL_NAME}
```

#### Probe Timing Guide

| Model | Startup Max | Liveness Period | Readiness Period |
|---|---|---|---|
| Phi-3 Mini (3.8B) | 2 minutes | 30s | 10s |
| Mistral 7B | 4 minutes | 30s | 10s |
| Qwen 2.5 7B | 4 minutes | 30s | 10s |
| Llama 3.1 8B | 5 minutes | 30s | 10s |
| DeepSeek 7B | 5 minutes | 30s | 10s |

---

### Resource Requests Per Model

```yaml
# Phi-3 Mini 3.8B
resources:
  requests: { memory: "10Gi", cpu: "2", nvidia.com/gpu: "1" }
  limits:   { memory: "16Gi", cpu: "4", nvidia.com/gpu: "1" }

# Mistral 7B / Qwen 2.5 7B (float16)
resources:
  requests: { memory: "16Gi", cpu: "4", nvidia.com/gpu: "1" }
  limits:   { memory: "24Gi", cpu: "8", nvidia.com/gpu: "1" }

# Llama 3.1 8B / DeepSeek 7B (float16)
resources:
  requests: { memory: "24Gi", cpu: "4", nvidia.com/gpu: "2" }
  limits:   { memory: "40Gi", cpu: "8", nvidia.com/gpu: "2" }

# Gemma 2 9B
resources:
  requests: { memory: "28Gi", cpu: "4", nvidia.com/gpu: "2" }
  limits:   { memory: "48Gi", cpu: "8", nvidia.com/gpu: "2" }
```

---

### HPA Configuration

```yaml
# k8s/models/llama-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llama-model-hpa
  namespace: ai-platform
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llama-model
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Pods
      pods:
        metric:
          name: inference_queue_depth
        target:
          type: AverageValue
          averageValue: "5"           # Scale up if queue > 5 requests per pod
    - type: External
      external:
        metric:
          name: nvidia_gpu_utilization
          selector:
            matchLabels:
              app: llama-model
        target:
          type: AverageValue
          averageValue: "75"          # Scale up if GPU > 75% utilised
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60           # Add 1 pod max per minute
    scaleDown:
      stabilizationWindowSeconds: 300 # Wait 5 min before scaling down
      policies:
        - type: Pods
          value: 1
          periodSeconds: 120
```

---

### PVC for Model Weights

```yaml
# k8s/models/llama-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: llama-weights
  namespace: ai-platform
spec:
  accessModes:
    - ReadOnlyMany               # Multiple replicas can mount same weights
  storageClassName: fast-nvme    # NVMe-backed storage class for fast load
  resources:
    requests:
      storage: 30Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mistral-weights
  namespace: ai-platform
spec:
  accessModes:
    - ReadOnlyMany
  storageClassName: fast-nvme
  resources:
    requests:
      storage: 20Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: qwen-weights
  namespace: ai-platform
spec:
  accessModes:
    - ReadOnlyMany
  storageClassName: fast-nvme
  resources:
    requests:
      storage: 20Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: deepseek-weights
  namespace: ai-platform
spec:
  accessModes:
    - ReadOnlyMany
  storageClassName: fast-nvme
  resources:
    requests:
      storage: 20Gi
```

---

### Node Affinity

```yaml
# Label GPU nodes during cluster setup:
# kubectl label node <gpu-node-1> nvidia.com/gpu=true nvidia.com/gpu.memory=80000
# kubectl label node <gpu-node-2> nvidia.com/gpu=true nvidia.com/gpu.memory=40000

# In each model deployment spec.template.spec:
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: nvidia.com/gpu.memory
              operator: Gt
              values: ["38000"]       # Llama / DeepSeek: need 40GB+ VRAM
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values: ["llama-model", "deepseek-model"]
          topologyKey: kubernetes.io/hostname
```

---

## Frontend Architecture

### Page -> Component -> Service Map

```
ChatPage
  +-- ConversationList       -> chatService.getConversations()
  +-- ModelSelector          -> modelService.getEnabledModels()
  +-- MessageThread
  |   +-- MessageBubble
  |   +-- ToolCallDisplay
  +-- ChatInput              -> chatService.sendMessage() [SSE stream]

ModelsPage
  +-- ModelCard              -> modelService.getModels()
  +-- ModelMetricsPanel      -> modelService.getMetrics(id)

DatasetsPage
  +-- DatasetUpload          -> datasetService.upload()
  +-- DatasetList            -> datasetService.list()

TrainingPage
  +-- TrainingJobForm        -> trainingService.submitJob()
  +-- TrainingJobList        -> trainingService.listJobs()
  +-- TrainingProgress       -> trainingService.getLogs(id) [SSE]
```

### Streaming Chat Hook

```typescript
// frontend/src/hooks/useStreamingResponse.ts
export function useStreamingResponse() {
  const [content, setContent] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);

  const stream = useCallback(async (request: ChatRequest) => {
    setIsStreaming(true);
    setContent("");

    const response = await fetch("/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`
      },
      body: JSON.stringify({ ...request, stream: true }),
    });

    const reader = response.body!.getReader();
    const decoder = new TextDecoder();

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const lines = decoder.decode(value).split("\n");
      for (const line of lines) {
        if (line.startsWith("data: ") && line !== "data: [DONE]") {
          const chunk = JSON.parse(line.slice(6));
          setContent(prev => prev + (chunk.delta?.content ?? ""));
        }
      }
    }
    setIsStreaming(false);
  }, []);

  return { content, isStreaming, stream };
}
```

---

## Backend Architecture

### Request Flow

```
HTTP Request
  -> FastAPI Router (api/v1/)
  -> Auth middleware (JWT validation + RBAC check)
  -> Rate limit middleware (Redis)
  -> Route handler (api/v1/chat.py)
  -> Service layer (services/chat_service.py)
     -> Repository layer (repositories/conversation_repo.py)  -> PostgreSQL
     -> Model router -> HTTP call to svc/<model>:8080
     -> Cache layer (Redis)
  -> StreamingResponse (SSE)
```

### Settings

```python
# backend/src/config/settings.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Enterprise AI Platform"
    DEBUG: bool = False
    SECRET_KEY: str

    DATABASE_URL: str                   # postgresql+asyncpg://...
    REDIS_URL: str                      # redis://redis:6379/0

    QDRANT_HOST: str = "qdrant"
    QDRANT_PORT: int = 6333

    # Injected by Kubernetes ConfigMap
    LLAMA_ENDPOINT: str = "http://llama-model:8080"
    MISTRAL_ENDPOINT: str = "http://mistral-model:8080"
    QWEN_ENDPOINT: str = "http://qwen-model:8080"
    DEEPSEEK_ENDPOINT: str = "http://deepseek-model:8080"

    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    class Config:
        env_file = ".env"
```

---

## Database Design

### PostgreSQL Schema

```sql
-- Users
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT UNIQUE NOT NULL,
    username    TEXT UNIQUE NOT NULL,
    hashed_pw   TEXT NOT NULL,
    role        TEXT NOT NULL DEFAULT 'user',
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- Conversations
CREATE TABLE conversations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT,
    model_id    UUID REFERENCES model_registry(id),
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Messages
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    role            TEXT NOT NULL,
    content         TEXT,
    tool_calls      JSONB,
    tool_call_id    TEXT,
    tokens_used     INT,
    latency_ms      INT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Model registry
CREATE TABLE model_registry (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT UNIQUE NOT NULL,
    display_name        TEXT NOT NULL,
    version             TEXT NOT NULL,
    endpoint_url        TEXT NOT NULL,
    gpu_count           INT,
    vram_gb             INT,
    max_context_length  INT DEFAULT 4096,
    is_enabled          BOOLEAN DEFAULT true,
    is_healthy          BOOLEAN DEFAULT true,
    active_adapter_id   UUID,
    created_at          TIMESTAMPTZ DEFAULT now()
);

-- Datasets
CREATE TABLE datasets (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name              TEXT NOT NULL,
    description       TEXT,
    format            TEXT NOT NULL,
    file_path         TEXT NOT NULL,
    file_size_bytes   BIGINT,
    row_count         INT,
    token_count_est   INT,
    version           INT DEFAULT 1,
    is_valid          BOOLEAN,
    validation_errors JSONB,
    uploaded_by       UUID REFERENCES users(id),
    created_at        TIMESTAMPTZ DEFAULT now()
);

-- Training jobs
CREATE TABLE training_jobs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name              TEXT NOT NULL,
    base_model_id     UUID REFERENCES model_registry(id),
    dataset_id        UUID REFERENCES datasets(id),
    training_type     TEXT NOT NULL,
    hyperparameters   JSONB NOT NULL,
    status            TEXT DEFAULT 'pending',
    celery_task_id    TEXT,
    train_loss        FLOAT,
    eval_loss         FLOAT,
    adapter_id        UUID,
    error_message     TEXT,
    started_at        TIMESTAMPTZ,
    completed_at      TIMESTAMPTZ,
    created_by        UUID REFERENCES users(id),
    created_at        TIMESTAMPTZ DEFAULT now()
);

-- Adapters
CREATE TABLE adapters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    version         TEXT NOT NULL,
    base_model_id   UUID REFERENCES model_registry(id),
    training_job_id UUID REFERENCES training_jobs(id),
    adapter_path    TEXT NOT NULL,
    is_deployed     BOOLEAN DEFAULT false,
    metrics         JSONB,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

## Model Serving Architecture

### Model Server (FastAPI per model)

```python
# model-services/llama/server.py
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import torch, os

app = FastAPI(title="Llama 3.1 8B Server")
MODEL_PATH = os.environ.get("MODEL_PATH", "/models/llama-3.1-8b")
model = None
tokenizer = None

@app.on_event("startup")
async def startup():
    global model, tokenizer
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH,
        torch_dtype=torch.float16,
        device_map="auto",
    )
    model.eval()

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    prompt = tokenizer.apply_chat_template(
        request.messages,
        tokenize=False,
        add_generation_prompt=True
    )
    inputs = tokenizer(prompt, return_tensors="pt").to("cuda")

    if request.stream:
        return StreamingResponse(
            _stream_generate(inputs, request),
            media_type="text/event-stream"
        )

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=request.max_tokens or 1024,
            temperature=request.temperature or 0.7,
            do_sample=True,
        )
    text = tokenizer.decode(
        output[0][inputs["input_ids"].shape[1]:],
        skip_special_tokens=True
    )
    return {"choices": [{"message": {"role": "assistant", "content": text}}]}

@app.post("/adapter/load")
async def load_adapter(body: AdapterLoadRequest):
    """Hot-swap LoRA adapter without restarting pod."""
    global model
    model = PeftModel.from_pretrained(model.base_model, body.adapter_path)
    return {"status": "loaded", "adapter": body.adapter_path}

@app.get("/metrics")
async def prometheus_metrics():
    # Expose: inference_queue_depth, tokens_per_second, gpu_utilization
    pass
```

---

## Training Pipeline

### LoRA Training Worker

```python
# backend/src/training/lora_trainer.py
from transformers import TrainingArguments, Trainer, AutoModelForCausalLM
from peft import LoraConfig, get_peft_model, TaskType
import torch

def run_lora_training(job: TrainingJob):
    # 1. Load base model
    model = AutoModelForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float16,
        device_map="auto",
    )

    # 2. Apply LoRA config
    lora_config = LoraConfig(
        r=job.hyperparameters["lora_rank"],
        lora_alpha=job.hyperparameters["lora_alpha"],
        target_modules=job.hyperparameters["lora_target_modules"],
        lora_dropout=job.hyperparameters["lora_dropout"],
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)

    # 3. Load + tokenize dataset
    dataset = load_and_tokenize(
        job.dataset_id,
        job.hyperparameters["max_seq_length"]
    )

    # 4. Train
    training_args = TrainingArguments(
        output_dir=f"/adapters/{job.id}",
        num_train_epochs=job.hyperparameters["epochs"],
        per_device_train_batch_size=job.hyperparameters["batch_size"],
        gradient_accumulation_steps=job.hyperparameters["gradient_accumulation_steps"],
        learning_rate=job.hyperparameters["learning_rate"],
        lr_scheduler_type=job.hyperparameters["lr_scheduler"],
        warmup_ratio=job.hyperparameters["warmup_ratio"],
        save_strategy="epoch",
        logging_steps=10,
        fp16=True,
        report_to="none",
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
        eval_dataset=dataset.get("validation"),
    )
    trainer.train()

    # 5. Save adapter only (not full model weights)
    model.save_pretrained(f"/adapters/{job.id}/final")
```

---

## Monitoring & Observability

### Prometheus Metrics Per Model Pod

```
# Inference metrics
inference_requests_total{model="llama-3.1-8b", status="success"}
inference_requests_total{model="llama-3.1-8b", status="error"}
inference_duration_seconds{model="llama-3.1-8b", quantile="0.5"}
inference_duration_seconds{model="llama-3.1-8b", quantile="0.95"}
inference_duration_seconds{model="llama-3.1-8b", quantile="0.99"}
inference_tokens_generated_total{model="llama-3.1-8b"}
inference_tokens_per_second{model="llama-3.1-8b"}
inference_queue_depth{model="llama-3.1-8b"}

# GPU metrics (via nvidia-dcgm-exporter)
DCGM_FI_DEV_GPU_UTIL{pod="llama-model-xxx"}
DCGM_FI_DEV_MEM_COPY_UTIL{pod="llama-model-xxx"}
DCGM_FI_DEV_FB_USED{pod="llama-model-xxx"}
DCGM_FI_DEV_FB_FREE{pod="llama-model-xxx"}
DCGM_FI_DEV_POWER_USAGE{pod="llama-model-xxx"}
DCGM_FI_DEV_GPU_TEMP{pod="llama-model-xxx"}
```

### Grafana Dashboard Panels Per Model

```
Row: "Llama 3.1 8B"
  +-- Request Rate (req/s)
  +-- Error Rate (%)
  +-- P50 / P95 / P99 Latency
  +-- Tokens/sec
  +-- Queue Depth
  +-- GPU Utilization (%)
  +-- GPU VRAM Used / Free
  +-- GPU Power Draw (W)
  +-- GPU Temperature (C)
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

```yaml
# .github/workflows/ci.yaml
name: CI
on: [push, pull_request]

jobs:
  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install -r backend/requirements-dev.txt
      - run: pytest backend/tests/ --cov=src --cov-report=xml

  test-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20" }
      - run: cd frontend && npm ci && npm test -- --coverage

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ruff mypy && ruff check backend/ && mypy backend/src/
```

```yaml
# .github/workflows/build-push.yaml
name: Build and Push
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service:
          - frontend
          - backend
          - llama-model
          - mistral-model
          - qwen-model
          - deepseek-model
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: ./${{ matrix.service }}
          push: true
          tags: ghcr.io/${{ github.repository }}/${{ matrix.service }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

```yaml
# .github/workflows/helm-deploy.yaml
name: Deploy to Kubernetes
on:
  workflow_run:
    workflows: ["Build and Push"]
    types: [completed]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - run: |
          helm upgrade --install llama-model ./helm/llama-model \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait --timeout 10m

          helm upgrade --install mistral-model ./helm/mistral-model \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait --timeout 8m

          helm upgrade --install qwen-model ./helm/qwen-model \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait --timeout 8m

          helm upgrade --install deepseek-model ./helm/deepseek-model \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait --timeout 8m

          helm upgrade --install chat-api ./helm/chat-api \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait

          helm upgrade --install frontend ./helm/frontend \
            --namespace ai-platform \
            --set image.tag=${{ github.sha }} \
            --wait
```

---

## Security

### RBAC Roles

| Role | Permissions |
|---|---|
| `admin` | Full access — manage users, models, all training jobs |
| `data_scientist` | Upload datasets, create training jobs, view all models |
| `trainer` | Create training jobs on own datasets only |
| `user` | Chat only — no training or model management |

### JWT Token Structure

```python
# Payload
{
  "sub": "user-uuid",
  "email": "user@org.com",
  "role": "data_scientist",
  "exp": 1234567890,
  "iat": 1234567890
}
```

### Network Policy

```yaml
# Only chat-api and training-api can reach model pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: model-pod-ingress
  namespace: ai-platform
spec:
  podSelector:
    matchLabels:
      role: model-server
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: chat-api
        - podSelector:
            matchLabels:
              app: training-api
      ports:
        - port: 8080
```

---

## API Reference

### Authentication

```http
POST /api/v1/auth/login
Content-Type: application/json

{ "email": "user@org.com", "password": "password" }
```

Response:

```json
{ "access_token": "eyJ...", "token_type": "bearer", "expires_in": 3600 }
```

### Common Headers

```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

### Error Response Format

```json
{
  "error": {
    "code": "MODEL_UNAVAILABLE",
    "message": "The requested model is currently offline",
    "model": "llama-3.1-8b"
  }
}
```

### Endpoints Summary

| Method | Path | Description |
|---|---|---|
| POST | /api/v1/auth/login | Login and get JWT |
| POST | /api/v1/chat/completions | Chat (streaming or batch) |
| GET | /api/v1/conversations | List conversations |
| GET | /api/v1/conversations/{id}/messages | Get messages |
| GET | /api/v1/models | List models |
| POST | /api/v1/models | Register model |
| POST | /api/v1/models/{id}/restart | Restart model pod |
| POST | /api/v1/datasets/upload | Upload dataset |
| GET | /api/v1/datasets/{id}/preview | Preview dataset rows |
| POST | /api/v1/training/jobs | Submit training job |
| GET | /api/v1/training/jobs/{id}/logs | Stream training logs |
| POST | /api/v1/adapters/{id}/deploy | Deploy adapter |
| POST | /api/v1/evaluation/run | Run evaluation |
| POST | /api/v1/rag/documents/upload | Upload RAG document |

---

## Environment Variables

### Backend (.env)

```bash
# App
APP_ENV=production
SECRET_KEY=your-secret-key-min-32-chars
DEBUG=false

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@postgres:5432/aiplatform
REDIS_URL=redis://redis:6379/0

# Qdrant
QDRANT_HOST=qdrant
QDRANT_PORT=6333

# Model endpoints (injected by Kubernetes ConfigMap)
LLAMA_ENDPOINT=http://llama-model:8080
MISTRAL_ENDPOINT=http://mistral-model:8080
QWEN_ENDPOINT=http://qwen-model:8080
DEEPSEEK_ENDPOINT=http://deepseek-model:8080

# Auth
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Storage
ADAPTER_STORAGE_PATH=/adapters
DATASET_STORAGE_PATH=/datasets

# Rate limiting
RATE_LIMIT_PER_MINUTE=60
```

---

## Local Development Setup

```bash
# 1. Clone the repository
git clone https://github.com/your-org/enterprise-ai-platform.git
cd enterprise-ai-platform

# 2. Start infrastructure (no GPU required)
docker compose up -d postgres redis qdrant

# 3. Start backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn src.main:app --reload --port 8000

# 4. Start frontend
cd frontend
npm install
npm run dev   # Vite dev server at http://localhost:5173

# 5. (Optional) Start a mock model server
cd model-services/mistral
pip install -r requirements.txt
uvicorn server:app --port 8081
# Then set in backend .env: MISTRAL_ENDPOINT=http://localhost:8081
```

---

## Deployment Guide

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Install infrastructure
helm upgrade --install postgres    ./helm/postgres    -n ai-platform --wait
helm upgrade --install redis       ./helm/redis       -n ai-platform --wait
helm upgrade --install qdrant      ./helm/qdrant      -n ai-platform --wait

# 3. Run DB migrations
kubectl create job --from=cronjob/db-migrate db-migrate-init -n ai-platform

# 4. Deploy model pods (one per model — independently)
helm upgrade --install llama-model    ./helm/llama-model    -n ai-platform --wait --timeout 10m
helm upgrade --install mistral-model  ./helm/mistral-model  -n ai-platform --wait --timeout 8m
helm upgrade --install qwen-model     ./helm/qwen-model     -n ai-platform --wait --timeout 8m
helm upgrade --install deepseek-model ./helm/deepseek-model -n ai-platform --wait --timeout 8m

# 5. Deploy application services
helm upgrade --install chat-api      ./helm/chat-api      -n ai-platform --wait
helm upgrade --install training-api  ./helm/training-api  -n ai-platform --wait
helm upgrade --install frontend      ./helm/frontend      -n ai-platform --wait

# 6. Deploy monitoring
helm upgrade --install monitoring ./helm/monitoring -n ai-platform --wait

# 7. Verify all pods
kubectl get pods -n ai-platform

# Expected:
# llama-model-xxx        1/1  Running
# mistral-model-xxx      1/1  Running
# qwen-model-xxx         1/1  Running
# deepseek-model-xxx     1/1  Running
# chat-api-xxx           1/1  Running
# training-api-xxx       1/1  Running
# frontend-xxx           1/1  Running
# postgres-xxx           1/1  Running
# redis-xxx              1/1  Running
# qdrant-xxx             1/1  Running
# prometheus-xxx         1/1  Running
# grafana-xxx            1/1  Running
```

---

## Future Enhancements

| Feature | Priority | Notes |
|---|---|---|
| vLLM model serving | High | Replace Transformers pipeline for 3-10x throughput |
| Multi-GPU tensor parallelism | High | For 70B+ models |
| OpenAI-compatible API layer | High | Drop-in replacement for OpenAI SDK clients |
| Distributed fine-tuning (FSDP) | Medium | Multi-node training jobs |
| KEDA auto scaling | Medium | Scale model pods to zero on idle |
| Agentic workflows | Medium | LangGraph / custom agent loop |
| Workflow builder | Medium | Visual drag-and-drop pipeline editor |
| MCP (Model Context Protocol) | Medium | Plug-and-play tool ecosystem |
| Multi-tenant support | Medium | Namespace-per-tenant isolation |
| Embedding model pods | Medium | Dedicated pods for sentence-transformers |
| Billing + usage tracking | Low | Token-based cost attribution per user |
| Model marketplace | Low | Download and register community models |
| RLHF / DPO training | Low | Human feedback fine-tuning pipeline |