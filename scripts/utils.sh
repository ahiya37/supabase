#!/bin/bash

##############################################################################
#                                                                            #
#                  פונקציות עזר לסקריפט התקנת Supabase                      #
#                                                                            #
##############################################################################

# צבעים
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# פונקציות הדפסה
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}           $1${CYAN}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# פונקציות יצירת סיסמאות ומפתחות
generate_password() {
    openssl rand -base64 48 | tr -d "=+/\n" | cut -c1-${1:-32}
}

generate_jwt_secret() {
    openssl rand -base64 64 | tr -d "=+/\n" | cut -c1-64
}

generate_jwt_token() {
    local secret=$1
    local role=$2

    docker run --rm python:3.11-slim bash -c "
pip install PyJWT cryptography --quiet && python3 << 'PYTHON_SCRIPT'
import jwt
from datetime import datetime, timedelta

jwt_secret = '''${secret}'''

payload = {
    'role': '${role}',
    'iss': 'supabase',
    'iat': int(datetime.now().timestamp()),
    'exp': int((datetime.now() + timedelta(days=3650)).timestamp())
}

token = jwt.encode(payload, jwt_secret, algorithm='HS256')
print(token)
PYTHON_SCRIPT
"
}

# פונקציות תיקון Docker Compose
fix_docker_compose() {
    local compose_file=$1

    print_info "מתקן docker-compose.yml - מסיר ports מ-supavisor..."

    # גיבוי
    cp "$compose_file" "${compose_file}.backup.$(date +%s)"

    # תיקון עם Python - הכי אמין!
    python3 << 'PYTHON_FIX'
import re

with open('docker-compose.yml', 'r') as f:
    lines = f.readlines()

new_lines = []
in_supavisor = False
skip_next_postgres_port = False

for i, line in enumerate(lines):
    # זיהוי תחילת supavisor
    if line.strip().startswith('supavisor:'):
        in_supavisor = True
        new_lines.append(line)
        continue

    # זיהוי סוף supavisor (service חדש)
    if in_supavisor and line.startswith('  ') and ':' in line and not line.startswith('    '):
        in_supavisor = False

    # דילוג על השורה עם ${POSTGRES_PORT}:5432
    if in_supavisor and '${POSTGRES_PORT}:5432' in line:
        continue

    new_lines.append(line)

with open('docker-compose.yml', 'w') as f:
    f.writelines(new_lines)

print("✅ Supavisor ports תוקן!")
PYTHON_FIX

    print_success "Supavisor ports הוסר - אין קונפליקט עם DB!"
}

add_db_ports() {
    local compose_file=$1
    local port=$2

    print_info "מוסיף ports ל-DB..."

    # בדוק אם כבר יש
    if grep -A 10 "^  db:" "$compose_file" | grep -q "    ports:"; then
        print_info "DB כבר יש לו ports"
        return
    fi

    # הוספה עם awk
    awk -v port="$port" '
    /^  db:/ { in_db = 1 }
    in_db && /image: supabase\/postgres/ {
        print
        print "    ports:"
        print "      - \"" port ":5432\""
        in_db = 0
        next
    }
    { print }
    ' "$compose_file" > "${compose_file}.tmp"

    mv "${compose_file}.tmp" "$compose_file"

    print_success "DB ports נוסף על פורט $port"
}

# פונקציית התקנת תלויות
install_dependencies() {
    print_info "מתקין כלים נדרשים..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl git openssl ufw fail2ban nginx certbot python3-certbot-nginx python3-pip gawk > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y -q curl git openssl firewalld fail2ban nginx certbot python3-certbot-nginx python3-pip gawk
    fi
    print_success "כל הכלים הותקנו בהצלחה!"
}

# פונקציית התקנת Tailscale
install_tailscale() {
    local auth_key=$1

    print_info "מתקין Tailscale..."

    curl -fsSL https://tailscale.com/install.sh | sh

    print_info "מתחבר ל-Tailscale..."
    tailscale up --authkey="${auth_key}" --hostname="supabase-${DOMAIN%%.*}" --accept-routes

    TAILSCALE_IP=$(tailscale ip -4)

    if [ -n "$TAILSCALE_IP" ]; then
        print_success "Tailscale הותקן! IP: ${TAILSCALE_IP}"
        return 0
    else
        print_error "נכשל להתחבר ל-Tailscale"
        return 1
    fi
}

# פונקציה להצגת הלוגו
print_logo() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
   _____ _    _ _____        ____       _    _____ ______
  / ____| |  | |  __ \ /\   |  _ \   /\| |  / ____|  ____|
 | (___ | |  | | |__) /  \  | |_) | /  ` | | (___ | |__
  \___ \| |  | |  ___/ /\ \ |  _ < / /\ \ |  \___ \|  __|
  ____) | |__| | |  / ____ \| |_) / ____ \| |____) | |____
 |_____/ \____/|_| /_/    \_\____/_/    \_\_|_____/|______|

EOF
    echo -e "${NC}"
    echo -e "${CYAN}        🎉 התקנה מובטחת של Supabase 🎉${NC}"
    echo -e "${WHITE}   עם תיקון supavisor שעובד 100% + Tailscale${NC}"
    echo ""
}
