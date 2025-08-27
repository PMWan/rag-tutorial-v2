#!/bin/bash

# AWS EC2 Deployment Script for Ollama RAG System
# Run this on your EC2 instance after launching

set -e

echo "🚀 Starting AWS deployment for Ollama RAG system..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "🔧 Installing dependencies..."
sudo apt install -y curl wget git nginx python3 python3-pip

# Install Ollama
echo "🤖 Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Install uv
echo "📚 Installing uv package manager..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

# Clone your repository (replace with your actual repo)
echo "📥 Cloning repository..."
git clone https://github.com/yourusername/rag-tutorial-v2.git
cd rag-tutorial-v2

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
uv sync

# Populate the database
echo "🗄️ Populating database..."
uv run python populate_database.py

# Create custom Ollama model
echo "🎯 Creating custom Ollama model..."
ollama create rag-boardgames -f rag-modelfile

# Setup systemd service for the API
echo "⚙️ Setting up systemd service..."
sudo tee /etc/systemd/system/rag-api.service > /dev/null <<EOF
[Unit]
Description=RAG API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/rag-tutorial-v2
Environment=PATH=/home/ubuntu/.cargo/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/ubuntu/.cargo/bin/uv run python api.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable rag-api
sudo systemctl start rag-api

# Setup Nginx reverse proxy
echo "🌐 Setting up Nginx..."
sudo tee /etc/nginx/sites-available/rag-api > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/rag-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Setup firewall
echo "🔥 Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Test the API
echo "🧪 Testing the API..."
sleep 10
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "How do you get out of jail in Monopoly?"}' \
  | jq .

echo "✅ Deployment complete!"
echo "🌐 Your RAG API is available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "📊 Check service status: sudo systemctl status rag-api"
echo "📝 View logs: sudo journalctl -u rag-api -f"


