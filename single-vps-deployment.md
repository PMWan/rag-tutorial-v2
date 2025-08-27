# Single VPS Deployment - Cost Effective RAG System

## Why Single VPS?

✅ **Cost**: $20-100/month vs $500-1000+ on AWS  
✅ **Simplicity**: One server, one deployment  
✅ **Control**: Full access to everything  
✅ **Performance**: Direct connections, no network latency  

## Recommended VPS Providers

| Provider | Specs | Monthly Cost | GPU Options |
|----------|-------|-------------|-------------|
| **Hetzner** | 8 vCPU, 32GB RAM | $40-80 | Dedicated GPU servers |
| **OVH** | 8 vCPU, 32GB RAM | $50-100 | GPU instances available |
| **DigitalOcean** | 8 vCPU, 32GB RAM | $80-160 | No GPU (CPU only) |
| **Linode** | 8 vCPU, 32GB RAM | $60-120 | GPU instances available |
| **Vultr** | 8 vCPU, 32GB RAM | $50-100 | GPU instances available |

## Architecture

```
Internet → Nginx → RAG API → Ollama (GPU) → ChromaDB
                    ↓
                PostgreSQL + Redis
```

## Single VPS Setup
