#!/bin/bash

# EC2 User Data Script for Ollama GPU Instance
set -e

echo "🚀 Setting up Ollama GPU instance..."

# Update system
apt-get update && apt-get upgrade -y

# Install required packages
apt-get install -y curl wget git nginx python3 python3-pip

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/ubuntu/.bashrc

# Create application directory
mkdir -p /opt/rag-system
cd /opt/rag-system

# Clone your repository (replace with your actual repo)
git clone https://github.com/yourusername/rag-tutorial-v2.git .
chown -R ubuntu:ubuntu /opt/rag-system

# Install Python dependencies
sudo -u ubuntu uv sync

# Populate the database
sudo -u ubuntu uv run python populate_database.py

# Create custom Ollama model
sudo -u ubuntu ollama create rag-boardgames -f rag-modelfile

# Setup systemd service for Ollama
cat > /etc/systemd/system/ollama.service <<EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Ollama
systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

# Setup Nginx to proxy Ollama API
cat > /etc/nginx/sites-available/ollama <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:11434;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# Setup firewall
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create health check endpoint
cat > /opt/rag-system/health.py <<EOF
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            try:
                # Check if Ollama is running
                result = subprocess.run(['systemctl', 'is-active', 'ollama'], 
                                      capture_output=True, text=True)
                ollama_status = result.stdout.strip() == 'active'
                
                response = {
                    'status': 'healthy' if ollama_status else 'unhealthy',
                    'ollama': ollama_status,
                    'timestamp': subprocess.run(['date'], capture_output=True, text=True).stdout.strip()
                }
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), HealthHandler)
    server.serve_forever()
EOF

# Setup health check service
cat > /etc/systemd/system/health-check.service <<EOF
[Unit]
Description=Health Check Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/rag-system
ExecStart=/usr/bin/python3 health.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start health check
systemctl daemon-reload
systemctl enable health-check
systemctl start health-check

# Wait for Ollama to be ready
echo "Waiting for Ollama to be ready..."
sleep 30

# Test Ollama
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.2", "prompt": "Hello", "stream": false}' \
  | jq .

echo "✅ EC2 GPU instance setup complete!"
echo "🤖 Ollama is running on port 11434"
echo "🏥 Health check available on port 8080"


