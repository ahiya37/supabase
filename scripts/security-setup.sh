#!/bin/bash

##############################################################################
#                                                                            #
#                    סקריפט הגדרות אבטחה למערכת                             #
#                                                                            #
##############################################################################

# ייבוא פונקציות עזר
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

setup_ssh_keys() {
    local ssh_public_key=$1

    print_info "מוסיף את המפתח הציבורי שלך ל-authorized_keys..."

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$ssh_public_key" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    print_success "מפתח SSH נוסף בהצלחה!"
}

configure_ssh() {
    local ssh_port=$1

    print_info "מגדיר SSH על פורט ${ssh_port}..."

    # גיבוי קובץ תצורה
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)

    # עדכון הגדרות SSH
    sed -i "s/^#*Port .*/Port ${ssh_port}/" /etc/ssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config

    # וידוא שהפורט הוגדר
    if ! grep -q "^Port ${ssh_port}" /etc/ssh/sshd_config; then
        echo "Port ${ssh_port}" >> /etc/ssh/sshd_config
    fi

    print_success "SSH הוגדר על פורט ${ssh_port}"
    print_warning "כניסה עם סיסמה הושבתה - רק עם מפתח!"
}

setup_firewall() {
    local ssh_port=$1
    local postgres_port=$2
    local use_ssl=$3
    local tailscale_installed=$4

    print_info "מגדיר UFW..."

    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ${ssh_port}/tcp comment 'SSH Custom Port'
    ufw allow 80/tcp comment 'HTTP'

    if [ "$use_ssl" = true ]; then
        ufw allow 443/tcp comment 'HTTPS'
    fi

    ufw allow ${postgres_port}/tcp comment 'PostgreSQL'

    if [[ $tailscale_installed -eq 0 ]]; then
        ufw allow 41641/udp comment 'Tailscale'
    fi

    ufw --force reload

    print_success "חומת האש הופעלה!"
}

setup_fail2ban() {
    local ssh_port=$1
    local config_dir=$2

    print_info "מגדיר Fail2Ban..."

    # אם יש קובץ תצורה מוכן, השתמש בו
    if [ -f "${config_dir}/fail2ban.conf" ]; then
        cp "${config_dir}/fail2ban.conf" /etc/fail2ban/jail.local
        sed -i "s/SSH_PORT_PLACEHOLDER/${ssh_port}/" /etc/fail2ban/jail.local
    else
        # אחרת, צור אותו ישירות
        cat > /etc/fail2ban/jail.local << F2BEOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ${ssh_port}
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
F2BEOF
    fi

    systemctl restart fail2ban
    systemctl enable fail2ban

    print_success "Fail2Ban הופעל!"
}

restart_ssh() {
    local ssh_port=$1

    print_info "רסטארט SSH על פורט ${ssh_port}..."
    systemctl restart sshd
    print_success "SSH הופעל מחדש!"
}

# הרצת הפונקציות במידה והסקריפט רץ ישירות
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 2 ]; then
        echo "שימוש: $0 <ssh_port> <postgres_port> [use_ssl] [tailscale_installed]"
        exit 1
    fi

    SSH_PORT=$1
    POSTGRES_PORT=$2
    USE_SSL=${3:-false}
    TAILSCALE_INSTALLED=${4:-1}

    print_header "הגדרת אבטחה"
    setup_firewall "$SSH_PORT" "$POSTGRES_PORT" "$USE_SSL" "$TAILSCALE_INSTALLED"
    setup_fail2ban "$SSH_PORT" "$(dirname $SCRIPT_DIR)/config"
fi
