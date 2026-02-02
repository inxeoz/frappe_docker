#!/bin/bash
# Server deployment script for nginx configuration
# Run this on your server: /root/inxeoz/

set -e

echo "🚀 Frappe Docker Server Setup Script"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Step 1: Deploy Docker containers
echo -e "\n📦 Step 1: Deploying Docker containers..."
cd frappe-deployment-package/

# Load images
print_status "Loading Docker images..."
docker load < frappe-images/traefik-v2.11.tar.gz
docker load < frappe-images/custom-15.tar.gz  
docker load < frappe-images/mariadb-11.8.tar.gz
docker load < frappe-images/redis-6.2-alpine.tar.gz
docker load < frappe-images/nginx-v0.18.0.tar.gz

# Deploy Traefik infrastructure
print_status "Starting Traefik infrastructure..."
docker compose -f compose.yaml -f overrides/compose.traefik-one.yaml --env-file traefik.env -p traefik up -d

# Wait for Traefik to be ready
print_status "Waiting for Traefik to initialize..."
sleep 10

# Deploy ALIS application
print_status "Starting ALIS application..."
docker compose -f compose.yaml -f overrides/compose.traefik-app.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml --env-file envs/alis.env -p alis up -d

# Verify deployment
echo -e "\n🔍 Checking deployment status..."
CONTAINER_COUNT=$(docker ps | grep -E "(traefik|alis)" | wc -l)
print_status "Running containers: $CONTAINER_COUNT"

if [ "$CONTAINER_COUNT" -lt 10 ]; then
    print_warning "Expected 16+ containers, got $CONTAINER_COUNT. Deployment may need more time."
else
    print_status "Deployment looks good!"
fi

# Step 2: Configure nginx
echo -e "\n🔧 Step 2: Configuring nginx..."
cd ..

# Backup current nginx config
if [ -f "/etc/nginx/nginx.conf" ]; then
    print_status "Backing up current nginx.conf..."
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Copy our nginx configuration
print_status "Installing Frappe nginx configuration..."
cp nginx.conf /etc/nginx/nginx.conf

# Test nginx configuration
print_status "Testing nginx configuration..."
if nginx -t; then
    print_status "Nginx configuration is valid"
    
    # Reload nginx
    print_status "Reloading nginx..."
    systemctl reload nginx
    
    if systemctl is-active --quiet nginx; then
        print_status "Nginx is running successfully"
    else
        print_error "Nginx failed to start"
        systemctl status nginx
        exit 1
    fi
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Step 3: Configure hosts file for testing
echo -e "\n🌐 Step 3: Configuring hosts file..."
if ! grep -q "s1.inxeoz.com" /etc/hosts; then
    print_status "Adding site hostnames to /etc/hosts..."
    echo "127.0.0.1 s1.inxeoz.com s2.inxeoz.com s3.inxeoz.com" >> /etc/hosts
else
    print_warning "Hostnames already exist in /etc/hosts"
fi

# Step 4: Test the setup
echo -e "\n🧪 Step 4: Testing the deployment..."

# Test Docker services
print_status "Testing Docker services..."
if curl -s -H "Host: s1.inxeoz.com" http://localhost:8100/ > /dev/null; then
    print_status "Traefik proxy is responding"
else
    print_warning "Traefik proxy test failed"
fi

# Test nginx proxy
print_status "Testing nginx proxy..."
if curl -s -H "Host: s1.inxeoz.com" http://localhost/ > /dev/null; then
    print_status "Nginx proxy is working"
else
    print_warning "Nginx proxy test failed"
fi

# Test health endpoints
if curl -s http://s1.inxeoz.com/nginx-health | grep -q "healthy"; then
    print_status "Health check endpoint is working"
else
    print_warning "Health check endpoint test failed"
fi

# Final status
echo -e "\n🎉 Deployment Complete!"
echo "=============================="
print_status "Access your sites:"
echo "   • ALIS:     http://s1.inxeoz.com"
echo "   • MAHAKAAL: http://s2.inxeoz.com"  
echo "   • SHIPRA:   http://s3.inxeoz.com"
echo ""
print_status "Running services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -10

echo ""
print_warning "Note: Make sure DNS/hosts are configured on client machines:"
echo "   Add to client /etc/hosts:"
echo "   [SERVER_IP] s1.inxeoz.com"
echo "   [SERVER_IP] s2.inxeoz.com"
echo "   [SERVER_IP] s3.inxeoz.com"

echo -e "\n📊 System Status:"
echo "   • Nginx: $(systemctl is-active nginx)"
echo "   • Docker: $(systemctl is-active docker)"
echo "   • Containers: $CONTAINER_COUNT running"

print_status "Setup completed successfully! 🚀"