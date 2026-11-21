#!/bin/bash
# ============================================
# Server Setup Script for stocks_products
# Run on server 194.113.34.240 as root or sudo
# ============================================

set -e

SERVER_USER="${1:-vylarrja}"
PROJECT_DIR="/home/${SERVER_USER}/crud"
REPO_URL="git@github.com:UvarovNik/crud.git"
DB_NAME="stocks_db"
DB_USER="stocks_user"
DB_PASS="$(openssl rand -base64 16)"
SECRET_KEY="$(python3 -c "import secrets; print('django-insecure-' + secrets.token_urlsafe(50))")"

echo "=== Updating system ==="
apt update && apt upgrade -y

echo "=== Installing system dependencies ==="
apt install -y python3 python3-pip python3-venv \
    postgresql postgresql-contrib \
    nginx \
    fail2ban \
    ufw \
    curl \
    git \
    libpq-dev \
    gcc

echo "=== Configuring PostgreSQL ==="
su - postgres -c "psql -c \"CREATE DATABASE ${DB_NAME};\"" 2>/dev/null || true
su - postgres -c "psql -c \"DO \\\$\\\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}'; END IF; END \\\$\\\$;\""
su - postgres -c "psql -c \"ALTER ROLE ${DB_USER} SET client_encoding TO 'utf8';\""
su - postgres -c "psql -c \"ALTER ROLE ${DB_USER} SET default_transaction_isolation TO 'read committed';\""
su - postgres -c "psql -c \"ALTER ROLE ${DB_USER} SET timezone TO 'UTC';\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};\""

echo "=== Setting up project directory ==="
cd /home/${SERVER_USER}
if [ -d crud ]; then
    cd crud && git fetch origin && git reset --hard origin/main
else
    git clone ${REPO_URL} crud
fi
cd crud

echo "=== Creating virtual environment ==="
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Creating .env file ==="
cat > .env << EOF
SECRET_KEY=${SECRET_KEY}
DEBUG=False
ALLOWED_HOSTS=194.113.34.240
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
EOF
chmod 600 .env

echo "=== Running migrations and collecting static ==="
python manage.py migrate
python manage.py collectstatic --noinput

echo "=== Creating Gunicorn systemd service ==="
sudo bash -c "cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=Gunicorn daemon for stocks_products
After=network.target

[Service]
User=${SERVER_USER}
Group=www-data
WorkingDirectory=${PROJECT_DIR}
Environment=PYTHONPATH=${PROJECT_DIR}/stocks_products
ExecStart=${PROJECT_DIR}/venv/bin/gunicorn --access-logfile - --error-logfile - --workers 3 --bind unix:${PROJECT_DIR}/gunicorn.sock stocks_products.wsgi:application
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

echo "=== Configuring Nginx ==="
sudo bash -c "cat > /etc/nginx/sites-available/stocks_products << 'EOF'
server {
    listen 80;
    server_name 194.113.34.240;

    add_header X-Frame-Options \"DENY\" always;
    add_header X-Content-Type-Options \"nosniff\" always;

    location /static/ {
        alias ${PROJECT_DIR}/stocks_products/staticfiles/;
    }

    location / {
        proxy_pass http://unix:${PROJECT_DIR}/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
EOF"

sudo ln -sf /etc/nginx/sites-available/stocks_products /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=== Configuring firewall ==="
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "=== Server setup complete! ==="
echo ""
echo "IMPORTANT: Save these credentials:"
echo "  DB Password: ${DB_PASS}"
echo "  SECRET_KEY: ${SECRET_KEY}"
echo ""
echo "API is available at: http://194.113.34.240/api/v1/"
echo "Admin panel at: http://194.113.34.240/admin/"
