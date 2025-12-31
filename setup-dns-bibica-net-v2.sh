#!/bin/bash

clear

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run this script with root privileges (sudo)"
    exit 1
fi

validate_domain() {
    local domain=$1
    [[ ${#domain} -le 253 ]] && \
    [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]] && \
    [[ ! "$domain" =~ \.\. ]]
}

validate_api_token() {
    [[ ${#1} -ge 40 ]]
}

verify_cloudflare_token() {
    local token=$1
    print_info "Verifying Cloudflare API Token..."
    
    # Call Cloudflare API to verify the token
    # Added --connect-timeout to prevent the script from hanging on network issues
    local response=$(curl -s --connect-timeout 10 -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json")
    
    # Check if the response contains success:true and the specific active message
    if [[ "$response" == *"\"success\":true"* ]] && [[ "$response" == *"This API Token is valid and active"* ]]; then
        return 0
    else
        return 1
    fi
}

echo "=========================================="
echo "    PUBLIC DNS SERVICE INSTALLATION"
echo "        (MOSDNS-X & CADDY STACK)"
echo "=========================================="
echo ""

while true; do
    read -p "Enter the domain you want to use (e.g., dns.bibica.net): " DOMAIN
    
    if validate_domain "$DOMAIN"; then
        print_success "Valid domain: $DOMAIN"
        break
    else
        print_error "Invalid domain. Please try again."
    fi
done

echo ""
echo "=========================================="
echo "        CLOUDFLARE API TOKEN"
echo "=========================================="
echo ""
echo "If you don't have an API Token yet, follow these steps:"
echo ""
echo "  1. Access: https://dash.cloudflare.com/profile/api-tokens"
echo "  2. Click 'Create Token'"
echo "  3. Choose Template: 'Edit zone DNS'"
echo "  4. Click 'Continue to summary' → 'Create Token'"
echo "  5. Copy the token"
echo ""
echo "API Token usually looks like: Aq9KZsM0yXHfV3BNe4cWb2tEPLoRrG8iJdYUh1m7F5O6k"
echo ""

while true; do
    read -p "Enter Cloudflare API Token: " API_TOKEN
    
    if validate_api_token "$API_TOKEN"; then
        if verify_cloudflare_token "$API_TOKEN"; then
            print_success "API Token is valid and active."
            break
        else
            print_error "API Token is incorrect or inactive. Please check your token and permissions."
        fi
    else
        print_error "Invalid API Token format (must be at least 40 characters). Please try again."
    fi
done

echo ""
print_info "Starting installation process..."
echo ""

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1
fi

cd /home || exit 1

curl -L https://github.com/bibicadotnet/dns.bibica.net.v2/archive/HEAD.tar.gz 2>/dev/null \
| tar xz --strip-components=1 \
&& rm -f LICENSE README.md \
&& chmod +x *.sh

if [ $? -ne 0 ]; then
    print_error "Unable to download project. Please check your internet connection."
    exit 1
fi

sed -i "s/CLOUDFLARE_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/CLOUDFLARE_API_TOKEN=$API_TOKEN/g" /home/compose.yml
sed -i "s/dns\.bibica\.net {/$DOMAIN {/g" /home/Caddyfile
sed -i "s/dns\.bibica\.net/$DOMAIN/g" /home/mosdns-x/config/config.yaml

cd /home || exit 1
docker compose up -d --build --remove-orphans --force-recreate > /dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Failed to initialize Docker. Please check for errors."
    exit 1
fi

/home/setup-cron-mosdns-block-allow.sh > /dev/null 2>&1

CERT_PATH="/home/caddy_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN"
MAX_WAIT=60
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if [ -f "$CERT_PATH/$DOMAIN.crt" ] && [ -f "$CERT_PATH/$DOMAIN.key" ] && [ -f "$CERT_PATH/$DOMAIN.json" ]; then
        break
    fi
    
    if [ $WAITED -eq 0 ]; then
        print_warning "Waiting for Caddy to generate SSL certificates..."
    fi
    
    sleep 5
    WAITED=$((WAITED + 5))
    
    if [ $WAITED -eq $MAX_WAIT ]; then
        print_warning "SSL certificates not generated after 60 seconds. Please check logs: docker logs caddy"
    fi
done

SERVER_IP=$(curl -s https://api.ipify.org)

echo ""
echo "=========================================="
echo "      INSTALLATION SUCCESSFUL!"
echo "=========================================="
echo ""
print_success "Public DNS service (Mosdns-x & Caddy) has been installed successfully!"
echo ""
echo "=========================================="
echo "          DNS CONFIGURATION"
echo "=========================================="
echo ""
print_warning "Please point your DNS record:"
echo "  - Name: $DOMAIN"
echo "  - Type: A"
echo "  - Value: $SERVER_IP"
echo ""
echo "=========================================="
echo "           USAGE INFORMATION"
echo "=========================================="
echo ""
echo "  DNS-over-HTTPS (DoH):" "  https://$DOMAIN/dns-query"
echo ""
echo "  DNS-over-TLS (DoT):" "  tls://$DOMAIN"
echo ""
echo "  DNS-over-HTTP/3 (DoH3):" "  h3://$DOMAIN/dns-query"
echo ""
echo "  DNS-over-QUIC (DoQ):" "  quic://$DOMAIN"
echo ""
echo "=========================================="
echo "          ADDITIONAL INFO"
echo "=========================================="
echo ""
echo "  - Core Engine: Mosdns-x (DNS Forwarder)"
echo "  - Web Server/SSL: Caddy v2 (Reverse Proxy)"
echo "  - Ad-blocking Cron: updates daily at 2:00 AM"
echo "  - Restart: cd /home && docker compose restart"
echo ""
print_success "Installation complete!"
