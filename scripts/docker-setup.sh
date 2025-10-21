#!/bin/bash

##############################################################################
#                                                                            #
#                  סקריפט התקנת Docker ו-Docker Compose                     #
#                                                                            #
##############################################################################

# ייבוא פונקציות עזר
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker אינו מותקן!"
        print_info "מתקין Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl start docker
        systemctl enable docker
        usermod -aG docker $USER
        print_success "Docker הותקן בהצלחה!"
        rm -f get-docker.sh
    else
        print_success "Docker כבר מותקן"
    fi
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose אינו מותקן!"
        print_info "מתקין Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose הותקן בהצלחה!"
    else
        print_success "Docker Compose כבר מותקן"
    fi
}

# הרצת הפונקציות
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    print_header "בדיקת והתקנת Docker"
    check_docker
    check_docker_compose
fi
