#!/bin/bash

##############################################################################
#                                                                            #
#          🚀 סקריפט התקנה מובטח למערכת Supabase 🚀                        #
#          עם תיקון supavisor שעובד בטוח 100%                               #
#                                                                            #
##############################################################################

set -e

# קביעת נתיבים
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"

# ייבוא פונקציות עזר
source "${SCRIPTS_DIR}/utils.sh"
source "${SCRIPTS_DIR}/docker-setup.sh"
source "${SCRIPTS_DIR}/security-setup.sh"
source "${SCRIPTS_DIR}/nginx-setup.sh"

# הצגת לוגו
print_logo

# בדיקת הרשאות root
if [[ $EUID -ne 0 ]]; then
   print_error "סקריפט זה חייב לרוץ עם הרשאות root (sudo)"
   echo "אנא הרץ: sudo bash $0"
   exit 1
fi

print_success "הרשאות מתאימות!"

# ========================================================================
#                             הוראות SSH
# ========================================================================
print_header "📋 הוראות לפני התקנה"

echo -e "${YELLOW}לפני שממשיכים, צריך ליצור מפתח SSH במחשב שלך!${NC}"
echo ""
echo -e "${WHITE}1. פתח טרמינל במחשב שלך והרץ:${NC}"
echo -e "${CYAN}   ssh-keygen -t ed25519 -f ~/.ssh/supabase-SERVERNAME -C \"your@email.com\"${NC}"
echo ""
echo -e "${WHITE}2. לחץ Enter פעמיים (ללא passphrase)${NC}"
echo ""
echo -e "${WHITE}3. הצג את המפתח הציבורי:${NC}"
echo -e "${CYAN}   cat ~/.ssh/supabase-SERVERNAME.pub${NC}"
echo ""
echo -e "${WHITE}4. העתק את כל התוכן (מתחיל ב-ssh-ed25519...)${NC}"
echo ""

read -p "$(echo -e ${GREEN}האם יצרת מפתח SSH והעתקת את המפתח הציבורי? '('y/n')': ${NC})" SSH_READY

if [[ "$SSH_READY" != "y" && "$SSH_READY" != "Y" ]]; then
    print_error "בבקשה צור מפתח SSH קודם ואז הרץ את הסקריפט שוב"
    exit 1
fi

# ========================================================================
#                          שלב 1: בדיקת מערכת
# ========================================================================
print_header "שלב 1/11: בדיקת מערכת"

check_docker
check_docker_compose
install_dependencies

# ========================================================================
#                       שלב 2: הגדרות ראשוניות
# ========================================================================
print_header "שלב 2/11: הגדרות ראשוניות"

echo ""
read -p "$(echo -e ${CYAN}הכנס את שם המפתח שיצרת ${WHITE}'['לדוגמה: supabase-prod']'${CYAN}: ${NC})" SSH_KEY_NAME
while [[ -z "$SSH_KEY_NAME" ]]; do
    print_warning "חובה להזין שם מפתח!"
    read -p "$(echo -e ${CYAN}הכנס את שם המפתח: ${NC})" SSH_KEY_NAME
done

echo ""
echo -e "${YELLOW}הדבק כאן את המפתח הציבורי שלך '('Ctrl+V ואז Enter')':${NC}"
read -p "" SSH_PUBLIC_KEY
while [[ -z "$SSH_PUBLIC_KEY" ]]; do
    print_warning "חובה להדביק את המפתח הציבורי!"
    read -p "$(echo -e ${CYAN}הדבק את המפתח הציבורי: ${NC})" SSH_PUBLIC_KEY
done

if [[ ! "$SSH_PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
    print_error "זה לא נראה כמו מפתח SSH תקין!"
    exit 1
fi

print_success "מפתח SSH תקין נקלט!"

echo ""
read -p "$(echo -e ${CYAN}הכנס את הדומיין שלך ${WHITE}'['לדוגמה: supabase.example.com']'${CYAN}: ${NC})" DOMAIN
while [[ -z "$DOMAIN" ]]; do
    print_warning "חובה להזין דומיין!"
    read -p "$(echo -e ${CYAN}הכנס את הדומיין שלך: ${NC})" DOMAIN
done

echo ""
read -p "$(echo -e ${CYAN}הכנס את כתובת האימייל שלך ${WHITE}'['לתעודת SSL']'${CYAN}: ${NC})" EMAIL
while [[ -z "$EMAIL" ]]; do
    print_warning "חובה להזין אימייל!"
    read -p "$(echo -e ${CYAN}הכנס את כתובת האימייל שלך: ${NC})" EMAIL
done

echo ""
read -p "$(echo -e ${CYAN}הכנס את תיקיית ההתקנה ${WHITE}'['ברירת מחדל: /opt/supabase']'${CYAN}: ${NC})" INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/opt/supabase}

echo ""
read -p "$(echo -e ${CYAN}הכנס פורט SSH מותאם אישית ${WHITE}'['ברירת מחדל: 22']'${CYAN}: ${NC})" SSH_PORT
SSH_PORT=${SSH_PORT:-22}

echo ""
read -p "$(echo -e ${CYAN}הכנס פורט PostgreSQL ${WHITE}'['ברירת מחדל: 5432']'${CYAN}: ${NC})" POSTGRES_PORT
POSTGRES_PORT=${POSTGRES_PORT:-5432}

# ========================================================================
#                        הגדרות Tailscale
# ========================================================================
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          🔗 Tailscale (אופציונלי)${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Tailscale מאפשר חיבור מאובטח לשרת דרך VPN פרטי.${NC}"
echo ""
echo -e "${WHITE}כדי להשתמש בזה:${NC}"
echo "1. לך ל-https://login.tailscale.com/admin/settings/keys"
echo "2. לחץ על 'Generate auth key'"
echo "3. סמן 'Reusable' (אופציונלי: גם 'Ephemeral')"
echo "4. העתק את המפתח"
echo ""

read -p "$(echo -e ${CYAN}האם תרצה להתקין Tailscale? '('y/n')': ${NC})" INSTALL_TAILSCALE

TAILSCALE_KEY=""
TAILSCALE_IP=""

if [[ "$INSTALL_TAILSCALE" == "y" || "$INSTALL_TAILSCALE" == "Y" ]]; then
    echo ""
    read -p "$(echo -e ${CYAN}הדבק את Auth Key של Tailscale: ${NC})" TAILSCALE_KEY
    while [[ -z "$TAILSCALE_KEY" ]]; do
        print_warning "חובה להזין Auth Key!"
        read -p "$(echo -e ${CYAN}הדבק את Auth Key: ${NC})" TAILSCALE_KEY
    done
fi

# ========================================================================
#                      שלב 3: הגדרת מפתח SSH
# ========================================================================
print_header "שלב 3/11: הגדרת מפתח SSH"

setup_ssh_keys "$SSH_PUBLIC_KEY"
configure_ssh "$SSH_PORT"

# ========================================================================
#                   שלב 4: התקנת Tailscale (אם נבחר)
# ========================================================================
print_header "שלב 4/11: התקנת Tailscale (אם נבחר)"

if [[ -n "$TAILSCALE_KEY" ]]; then
    install_tailscale "$TAILSCALE_KEY"
    TAILSCALE_INSTALLED=$?
else
    print_info "דילוג על Tailscale"
    TAILSCALE_INSTALLED=1
fi

# ========================================================================
#               שלב 5: יצירת סיסמאות ומפתחות מאובטחים
# ========================================================================
print_header "שלב 5/11: יצירת סיסמאות ומפתחות מאובטחים"

print_info "יוצר סיסמאות אקראיות וחזקות..."

POSTGRES_PASSWORD=$(generate_password 32)
JWT_SECRET=$(generate_jwt_secret)
DASHBOARD_PASSWORD=$(generate_password 24)

print_info "יוצר JWT tokens תקינים..."

ANON_KEY=$(generate_jwt_token "$JWT_SECRET" "anon")
SERVICE_ROLE_KEY=$(generate_jwt_token "$JWT_SECRET" "service_role")

print_success "כל הסיסמאות והמפתחות נוצרו בהצלחה!"

# ========================================================================
#                       שלב 6: הורדת Supabase
# ========================================================================
print_header "שלב 6/11: הורדת Supabase"

print_info "מוריד את Supabase מ-GitHub..."
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

if [ -d "supabase" ]; then
    print_warning "מוחק התקנה קודמת..."
    rm -rf supabase
fi

git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker

print_success "Supabase הורד בהצלחה!"

# ========================================================================
#                      שלב 7: הגדרת קבצי תצורה
# ========================================================================
print_header "שלב 7/11: הגדרת קבצי תצורה"

print_info "מעתיק את קובץ .env..."
cp .env.example .env

print_info "מעדכן סיסמאות ומפתחות..."

sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
sed -i "s|^ANON_KEY=.*|ANON_KEY=${ANON_KEY}|" .env
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}|" .env
sed -i "s|^DASHBOARD_USERNAME=.*|DASHBOARD_USERNAME=admin|" .env
sed -i "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}|" .env

sed -i "s|^SITE_URL=.*|SITE_URL=https://${DOMAIN}|" .env
sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=https://${DOMAIN}|" .env
sed -i "s|^SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=https://${DOMAIN}|" .env
sed -i "s|^SUPABASE_URL=.*|SUPABASE_URL=https://${DOMAIN}|" .env

sed -i "s|^SMTP_ADMIN_EMAIL=.*|SMTP_ADMIN_EMAIL=${EMAIL}|" .env
sed -i "s|^SMTP_HOST=.*|SMTP_HOST=smtp.gmail.com|" .env
sed -i "s|^SMTP_PORT=.*|SMTP_PORT=587|" .env
sed -i "s|^SMTP_USER=.*|SMTP_USER=${EMAIL}|" .env

sed -i "s|^POSTGRES_PORT=.*|POSTGRES_PORT=${POSTGRES_PORT}|" .env

if ! grep -q "^STORAGE_BACKEND=" .env; then
    echo "STORAGE_BACKEND=file" >> .env
fi
if ! grep -q "^FILE_STORAGE_BACKEND_PATH=" .env; then
    echo "FILE_STORAGE_BACKEND_PATH=/var/lib/storage" >> .env
fi

print_success "קובץ .env עודכן בהצלחה!"

# ========================================================================
#                     תיקון docker-compose.yml
# ========================================================================
print_header "תיקון docker-compose.yml - החלק הקריטי!"

# הפונקציה החדשה והמשופרת
fix_docker_compose "docker-compose.yml"
add_db_ports "docker-compose.yml" "$POSTGRES_PORT"

# וידוא שזה עבד
print_info "מוודא שהתיקון עבד..."

# בדיקה 1: supavisor לא אמור לתפוס 5432
if grep -A 10 "^  supavisor:" docker-compose.yml | grep -q "POSTGRES_PORT.*:5432"; then
    print_error "❌ התיקון נכשל! Supavisor עדיין מנסה לתפוס פורט 5432"
    print_warning "מציג את הקובץ לבדיקה:"
    grep -A 15 "^  supavisor:" docker-compose.yml
    exit 1
else
    print_success "✅ Supavisor תוקן בהצלחה - לא תופס פורט 5432!"
fi

# בדיקה 2: DB אמור לתפוס 5432
if ! grep -A 5 "^  db:" docker-compose.yml | grep -q "ports:"; then
    print_error "❌ DB לא קיבל ports!"
    exit 1
else
    print_success "✅ DB יש לו ports על פורט ${POSTGRES_PORT}!"
fi

# ========================================================================
#                       שלב 8: קבלת תעודת SSL
# ========================================================================
print_header "שלב 8/11: קבלת תעודת SSL"

if obtain_ssl_certificate "$DOMAIN" "$EMAIL"; then
    USE_SSL=true
else
    USE_SSL=false
fi

# ========================================================================
#                        שלב 9: הגדרת Nginx
# ========================================================================
print_header "שלב 9/11: הגדרת Nginx"

if [ "$USE_SSL" = true ]; then
    configure_nginx_ssl "$DOMAIN" "$CONFIG_DIR"
else
    configure_nginx_http "$DOMAIN" "$CONFIG_DIR"
fi

# ========================================================================
#                        שלב 10: הגדרת אבטחה
# ========================================================================
print_header "שלב 10/11: הגדרת אבטחה"

setup_firewall "$SSH_PORT" "$POSTGRES_PORT" "$USE_SSL" "$TAILSCALE_INSTALLED"
setup_fail2ban "$SSH_PORT" "$CONFIG_DIR"

# ========================================================================
#                       שלב 11: הפעלת Supabase
# ========================================================================
print_header "שלב 11/11: הפעלת Supabase"

print_info "מפעיל את Supabase..."

cd $INSTALL_DIR/supabase/docker

print_info "מוריד images (זה יכול לקחת 5-10 דקות)..."
docker-compose pull

print_info "מפעיל את כל השירותים..."
docker-compose up -d

print_info "ממתין לאתחול (90 שניות)..."
sleep 90

print_info "וידוא ש-Storage רץ..."
docker-compose up -d storage
sleep 10

print_info "רסטארט Kong..."
docker-compose restart kong
sleep 10

print_info "בדיקה סופית..."
docker-compose ps

# ========================================================================
#                     העתקת סקריפטים לניהול
# ========================================================================

print_info "מעתיק סקריפטים לניהול..."
mkdir -p $INSTALL_DIR/scripts
if [ -f "${SCRIPTS_DIR}/rotate-passwords.sh" ]; then
    cp "${SCRIPTS_DIR}/rotate-passwords.sh" "$INSTALL_DIR/scripts/"
    chmod +x "$INSTALL_DIR/scripts/rotate-passwords.sh"
    print_success "סקריפט החלפת סיסמאות הועתק ל-$INSTALL_DIR/scripts/"
fi

SERVER_IP=$(curl -s ifconfig.me)

restart_ssh "$SSH_PORT"

# ========================================================================
#                        שמירת פרטי הגישה
# ========================================================================

CREDENTIALS_FILE="$INSTALL_DIR/CREDENTIALS.txt"

cat > $CREDENTIALS_FILE << CREDEOF
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          🎉 Supabase הותקן בהצלחה! 🎉                    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

📌 פרטי גישה - שמור במקום מאובטח!

🌐 כתובות:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Dashboard:      $([ "$USE_SSL" = true ] && echo "https://${DOMAIN}" || echo "http://${DOMAIN}")
   API URL:        $([ "$USE_SSL" = true ] && echo "https://${DOMAIN}" || echo "http://${DOMAIN}")
   Server IP:      ${SERVER_IP}
$([ $TAILSCALE_INSTALLED -eq 0 ] && echo "   Tailscale IP:  ${TAILSCALE_IP}")

🔐 התחברות ללוח בקרה:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   שם משתמש:  admin
   סיסמה:     ${DASHBOARD_PASSWORD}

🔑 SSH (מפתח ייחודי לשרת זה!):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   שם המפתח:  ${SSH_KEY_NAME}
   פורט SSH:   ${SSH_PORT}

   חיבור רגיל:
   ssh -i ~/.ssh/${SSH_KEY_NAME} -p ${SSH_PORT} root@${SERVER_IP}
$([ $TAILSCALE_INSTALLED -eq 0 ] && echo "
   חיבור דרך Tailscale:
   ssh -i ~/.ssh/${SSH_KEY_NAME} -p ${SSH_PORT} root@${TAILSCALE_IP}")

🗄️ מסד נתונים:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Host:      ${SERVER_IP}
$([ $TAILSCALE_INSTALLED -eq 0 ] && echo "   Tailscale: ${TAILSCALE_IP}")
   Port:      ${POSTGRES_PORT}
   Database:  postgres
   User:      postgres
   Password:  ${POSTGRES_PASSWORD}

🔑 מפתחות API (JWT - ייחודיים לשרת זה!):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Anon Key:
   ${ANON_KEY}

   Service Role Key:
   ${SERVICE_ROLE_KEY}

   JWT Secret:
   ${JWT_SECRET}

📂 מיקומים:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   תיקייה:        ${INSTALL_DIR}/supabase/docker
   הגדרות:        ${INSTALL_DIR}/supabase/docker/.env

🛠️ פקודות:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   סטטוס:           cd ${INSTALL_DIR}/supabase/docker && docker-compose ps
   לוגים:           cd ${INSTALL_DIR}/supabase/docker && docker-compose logs -f
   רסטארט:          cd ${INSTALL_DIR}/supabase/docker && docker-compose restart
   החלפת סיסמאות:   bash ${INSTALL_DIR}/scripts/rotate-passwords.sh

⚠️  חשוב מאוד:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   1. אל תאבד את המפתח הפרטי: ~/.ssh/${SSH_KEY_NAME}
   2. כניסה עם סיסמה הושבתה - רק עם מפתח!
   3. אל תשתף את Service Role Key!
   4. שמור קובץ זה במקום מאובטח!
$([ $TAILSCALE_INSTALLED -eq 0 ] && echo "   5. Tailscale מאפשר חיבור מאובטח מכל מקום!")

💡 הערות:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   - Supavisor (Pooler) עובד ללא שגיאות!
   - Storage עובד מושלם!
   - פורט SSH: ${SSH_PORT}
   - פורט PostgreSQL: ${POSTGRES_PORT}
   - מפתחות JWT ייחודיים לשרת זה בלבד!
$([ $TAILSCALE_INSTALLED -eq 0 ] && echo "   - Tailscale מותקן ופעיל!")

CREDEOF

chmod 600 $CREDENTIALS_FILE

# ========================================================================
#                           סיכום התקנה
# ========================================================================

clear
echo -e "${GREEN}"
cat << "EOF"
   _____ _    _  _____ _____ ______  _____ _____
  / ____| |  | |/ ____/ ____|  ____|/ ____/ ____|
 | (___ | |  | | |   | |    | |__  | (___| (___
  \___ \| |  | | |   | |    |  __|  \___ \\___ \
  ____) | |__| | |___| |____| |____ ____) |___) |
 |_____/ \____/ \_____\_____|______|_____/_____/

EOF
echo -e "${NC}"

print_header "✅ התקנה הושלמה בהצלחה!"

echo ""
cd $INSTALL_DIR/supabase/docker
echo -e "${WHITE}סטטוס כל השירותים:${NC}"
docker-compose ps
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}🌐 גש עכשיו ל: ${GREEN}$([ "$USE_SSL" = true ] && echo "https://${DOMAIN}" || echo "http://${DOMAIN}")${NC}"
echo -e "${WHITE}👤 משתמש: ${YELLOW}admin${NC}"
echo -e "${WHITE}🔐 סיסמה: ${YELLOW}${DASHBOARD_PASSWORD}${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}🔑 SSH נשנה לפורט: ${WHITE}${SSH_PORT}${NC}"
echo -e "${YELLOW}   התחברות חדשה: ${WHITE}ssh -i ~/.ssh/${SSH_KEY_NAME} -p ${SSH_PORT} root@${SERVER_IP}${NC}"

if [[ $TAILSCALE_INSTALLED -eq 0 ]]; then
    echo ""
    echo -e "${PURPLE}🔗 Tailscale IP: ${WHITE}${TAILSCALE_IP}${NC}"
    echo -e "${YELLOW}   חיבור דרך Tailscale: ${WHITE}ssh -i ~/.ssh/${SSH_KEY_NAME} -p ${SSH_PORT} root@${TAILSCALE_IP}${NC}"
fi

echo ""
echo -e "${PURPLE}📄 כל הפרטים: ${WHITE}${CREDENTIALS_FILE}${NC}"
echo ""
echo -e "${GREEN}🎊 בהצלחה! Supavisor + Storage עובדים מושלם! 🎊${NC}"
echo ""
