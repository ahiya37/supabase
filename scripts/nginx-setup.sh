#!/bin/bash

##############################################################################
#                                                                            #
#                      סקריפט הגדרת Nginx ו-SSL                              #
#                                                                            #
##############################################################################

# ייבוא פונקציות עזר
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

obtain_ssl_certificate() {
    local domain=$1
    local email=$2

    print_info "מקבל תעודת SSL מ-Let's Encrypt..."

    # עצור Nginx אם רץ
    systemctl stop nginx 2>/dev/null || true

    certbot certonly --standalone -d ${domain} --non-interactive --agree-tos -m ${email}

    if [ ! -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]; then
        print_error "נכשל לקבל תעודת SSL!"
        print_warning "ממשיך בלי SSL (HTTP בלבד)"
        return 1
    else
        print_success "תעודת SSL נוצרה בהצלחה!"
        return 0
    fi
}

configure_nginx_ssl() {
    local domain=$1
    local config_dir=$2

    print_info "מגדיר Nginx עם SSL..."

    # אם יש קובץ תצורה מוכן, השתמש בו
    if [ -f "${config_dir}/nginx-ssl.conf" ]; then
        cp "${config_dir}/nginx-ssl.conf" /etc/nginx/sites-available/supabase
        sed -i "s/DOMAIN_PLACEHOLDER/${domain}/g" /etc/nginx/sites-available/supabase
    else
        # אחרת, צור אותו ישירות
        cat > /etc/nginx/sites-available/supabase << 'NGINXEOF'
upstream supabase_backend {
    server localhost:8000;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;

    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    client_max_body_size 50M;
    client_body_buffer_size 10M;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://supabase_backend;
    }
}
NGINXEOF
        sed -i "s|DOMAIN_PLACEHOLDER|${domain}|g" /etc/nginx/sites-available/supabase
    fi

    enable_nginx_site
}

configure_nginx_http() {
    local domain=$1
    local config_dir=$2

    print_info "מגדיר Nginx ללא SSL (HTTP)..."

    # אם יש קובץ תצורה מוכן, השתמש בו
    if [ -f "${config_dir}/nginx-http.conf" ]; then
        cp "${config_dir}/nginx-http.conf" /etc/nginx/sites-available/supabase
        sed -i "s/DOMAIN_PLACEHOLDER/${domain}/g" /etc/nginx/sites-available/supabase
    else
        # אחרת, צור אותו ישירות
        cat > /etc/nginx/sites-available/supabase << 'NGINXEOF'
upstream supabase_backend {
    server localhost:8000;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    client_max_body_size 50M;
    client_body_buffer_size 10M;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://supabase_backend;
    }
}
NGINXEOF
        sed -i "s|DOMAIN_PLACEHOLDER|${domain}|g" /etc/nginx/sites-available/supabase
    fi

    enable_nginx_site
}

enable_nginx_site() {
    print_info "מפעיל את אתר Nginx..."

    ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # בדוק תקינות התצורה
    if nginx -t; then
        systemctl start nginx
        systemctl enable nginx
        print_success "Nginx הוגדר והופעל בהצלחה!"
    else
        print_error "שגיאה בתצורת Nginx!"
        return 1
    fi
}

# הרצת הפונקציות במידה והסקריפט רץ ישירות
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 2 ]; then
        echo "שימוש: $0 <domain> <email> [use_ssl]"
        exit 1
    fi

    DOMAIN=$1
    EMAIL=$2
    USE_SSL=${3:-true}

    CONFIG_DIR="$(dirname $SCRIPT_DIR)/config"

    print_header "הגדרת Nginx"

    if [ "$USE_SSL" = "true" ]; then
        if obtain_ssl_certificate "$DOMAIN" "$EMAIL"; then
            configure_nginx_ssl "$DOMAIN" "$CONFIG_DIR"
        else
            configure_nginx_http "$DOMAIN" "$CONFIG_DIR"
        fi
    else
        configure_nginx_http "$DOMAIN" "$CONFIG_DIR"
    fi
fi
