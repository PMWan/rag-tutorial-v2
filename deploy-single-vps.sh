#!/bin/bash

# Single VPS Deployment Script for RAG System
# Run this on your VPS after initial setup

set -e

echo "🚀 Deploying RAG System on Single VPS"

# Configuration
DOMAIN="your-domain.com"
EMAIL="your-email@example.com"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Step 1: Update System${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}Step 2: Install Dependencies${NC}"
apt install -y curl wget git nginx postgresql postgresql-contrib redis-server python3 python3-pip python3-venv certbot python3-certbot-nginx

echo -e "${GREEN}Step 3: Install Ollama${NC}"
curl -fsSL https://ollama.ai/install.sh | sh

echo -e "${GREEN}Step 4: Install uv${NC}"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

echo -e "${GREEN}Step 5: Setup PostgreSQL${NC}"
# Create database and user
sudo -u postgres psql <<EOF
CREATE DATABASE ragdb;
CREATE USER raguser WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE ragdb TO raguser;
\c ragdb
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    api_key VARCHAR(255) UNIQUE NOT NULL,
    subscription_tier VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT NOW(),
    last_active TIMESTAMP
);
CREATE TABLE query_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sources JSONB,
    response_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    filename VARCHAR(255) NOT NULL,
    file_size BIGINT,
    document_type VARCHAR(50),
    upload_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'processing'
);
CREATE TABLE api_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    endpoint VARCHAR(100),
    response_time_ms INTEGER,
    status_code INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
EOF

echo -e "${GREEN}Step 6: Setup Redis${NC}"
# Configure Redis for persistence
sed -i 's/# save 900 1/save 900 1/' /etc/redis/redis.conf
sed -i 's/# save 300 10/save 300 10/' /etc/redis/redis.conf
sed -i 's/# save 60 10000/save 60 10000/' /etc/redis/redis.conf
systemctl restart redis-server

echo -e "${GREEN}Step 7: Clone and Setup RAG Application${NC}"
cd /opt
git clone https://github.com/yourusername/rag-tutorial-v2.git rag-system
cd rag-system

# Install Python dependencies
uv sync

# Populate the database
uv run python populate_database.py

# Create custom Ollama model
ollama create rag-boardgames -f rag-modelfile

echo -e "${GREEN}Step 8: Create Application User${NC}"
useradd -m -s /bin/bash raguser
chown -R raguser:raguser /opt/rag-system

echo -e "${GREEN}Step 9: Setup Systemd Services${NC}"

# Ollama service
cat > /etc/systemd/system/ollama.service <<EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=raguser
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10
Environment=OLLAMA_HOST=0.0.0.0

[Install]
WantedBy=multi-user.target
EOF

# RAG API service
cat > /etc/systemd/system/rag-api.service <<EOF
[Unit]
Description=RAG API Service
After=network.target postgresql.service redis-server.service ollama.service

[Service]
Type=simple
User=raguser
WorkingDirectory=/opt/rag-system
Environment=PATH=/home/raguser/.cargo/bin:/usr/local/bin:/usr/bin:/bin
Environment=DATABASE_URL=postgresql://raguser:secure_password@localhost:5432/ragdb
Environment=REDIS_URL=redis://localhost:6379
Environment=OLLAMA_HOST=localhost:11434
ExecStart=/home/raguser/.cargo/bin/uv run python api.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable ollama rag-api postgresql redis-server
systemctl start ollama rag-api

echo -e "${GREEN}Step 10: Setup Nginx${NC}"
cat > /etc/nginx/sites-available/rag-api <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support for streaming
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8000/health;
        access_log off;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/rag-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo -e "${GREEN}Step 11: Setup SSL Certificate${NC}"
if [ "$DOMAIN" != "your-domain.com" ]; then
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL
fi

echo -e "${GREEN}Step 12: Setup Firewall${NC}"
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

echo -e "${GREEN}Step 13: Create Monitoring Script${NC}"
cat > /opt/rag-system/monitor.sh <<'EOF'
#!/bin/bash
# Simple monitoring script

echo "=== RAG System Status ==="
echo "Ollama: $(systemctl is-active ollama)"
echo "RAG API: $(systemctl is-active rag-api)"
echo "PostgreSQL: $(systemctl is-active postgresql)"
echo "Redis: $(systemctl is-active redis-server)"
echo "Nginx: $(systemctl is-active nginx)"

echo -e "\n=== Memory Usage ==="
free -h

echo -e "\n=== Disk Usage ==="
df -h

echo -e "\n=== Recent API Logs ==="
journalctl -u rag-api --since "10 minutes ago" | tail -10
EOF

chmod +x /opt/rag-system/monitor.sh

echo -e "${GREEN}Step 14: Test the System${NC}"
sleep 10

# Test API
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "How do you get out of jail in Monopoly?"}' \
  | jq .

echo -e "${GREEN}✅ Single VPS deployment complete!${NC}"
echo -e "${YELLOW}🌐 Your RAG API is available at: http://$DOMAIN${NC}"
echo -e "${YELLOW}📊 Monitor system: /opt/rag-system/monitor.sh${NC}"
echo -e "${YELLOW}📝 View logs: journalctl -u rag-api -f${NC}"
echo -e "${YELLOW}🔧 Restart services: systemctl restart rag-api ollama${NC}"


