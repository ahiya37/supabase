#!/bin/bash
set -e

echo "🔐 סקריפט החלפת סיסמאות Supabase - מלא ואוטומטי"
echo "================================================"
echo ""

# נווט לתיקיית Supabase
cd /opt/supabase/supabase/docker || { echo "❌ שגיאה: לא מצאתי את תיקיית Supabase"; exit 1; }

# שלב 1: גיבוי
echo "📦 שלב 1/8: יצירת גיבוי של .env..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp .env .env.backup-$TIMESTAMP
echo "✅ גיבוי נוצר: .env.backup-$TIMESTAMP"
echo ""

# שלב 2: יצירת סיסמאות חדשות
echo "🎲 שלב 2/8: יצירת סיסמאות חדשות..."
NEW_POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
NEW_DASHBOARD_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-24)
NEW_PG_META_CRYPTO_KEY=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
NEW_SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '=+/' | cut -c1-64)
NEW_VAULT_ENC_KEY=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
echo "✅ סיסמאות חדשות נוצרו"
echo ""

# שלב 3: יצירת JWT Secrets
echo "🔑 שלב 3/8: יצירת JWT secrets..."
NEW_JWT_SECRET=$(openssl rand -base64 64 | tr -d '=+/' | cut -c1-64)

# יצירת סקריפט Python זמני
cat > /tmp/generate_jwt_tokens.py << 'PYEOF'
import jwt
import os
import sys
from datetime import datetime, timedelta

jwt_secret = os.environ.get('JWT_SECRET')
if not jwt_secret:
    print("Error: JWT_SECRET not set", file=sys.stderr)
    sys.exit(1)

# ANON_KEY
anon_payload = {
    "role": "anon",
    "iss": "supabase",
    "iat": int(datetime.now().timestamp()),
    "exp": int((datetime.now() + timedelta(days=3650)).timestamp())
}
anon_key = jwt.encode(anon_payload, jwt_secret, algorithm="HS256")

# SERVICE_ROLE_KEY
service_payload = {
    "role": "service_role",
    "iss": "supabase",
    "iat": int(datetime.now().timestamp()),
    "exp": int((datetime.now() + timedelta(days=3650)).timestamp())
}
service_key = jwt.encode(service_payload, jwt_secret, algorithm="HS256")

print(f"ANON_KEY={anon_key}")
print(f"SERVICE_ROLE_KEY={service_key}")
PYEOF

# הרץ את הסקריפט עם ה-JWT secret כמשתנה סביבה
JWT_TOKENS=$(JWT_SECRET="$NEW_JWT_SECRET" python3 /tmp/generate_jwt_tokens.py)

# קרא את הערכים שנוצרו
eval $(echo "$JWT_TOKENS" | sed 's/^/NEW_/')

# נקה סקריפט זמני
rm -f /tmp/generate_jwt_tokens.py

echo "✅ JWT tokens נוצרו"
echo ""

# שלב 4: עצירת שירותים
echo "🛑 שלב 4/8: עוצר שירותים..."
docker compose down
sleep 5
echo "✅ שירותים נעצרו"
echo ""

# שלב 5: הפעלת מסד נתונים בלבד
echo "🔄 שלב 5/8: מפעיל את מסד הנתונים..."
docker compose up -d db
sleep 10

# המתנה למסד נתונים
echo "⏳ מחכה שמסד הנתונים יהיה מוכן..."
for i in {1..30}; do
    if docker exec supabase-db pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ מסד הנתונים מוכן!"
        break
    fi
    sleep 1
done
echo ""

# שלב 6: תיקון הרשאות superuser
echo "🔧 שלב 6/8: בדיקה ותיקון הרשאות superuser..."
IS_SUPERUSER=$(docker exec supabase-db psql -h 127.0.0.1 -U postgres -d postgres -t -c "SELECT rolsuper FROM pg_roles WHERE rolname = 'postgres';" | xargs)

if [ "$IS_SUPERUSER" != "t" ]; then
    echo "⚠️  משתמש postgres איבד הרשאות superuser - מתקן..."
    docker exec supabase-db psql -h 127.0.0.1 -U supabase_admin -d postgres -c "ALTER USER postgres WITH SUPERUSER;" > /dev/null
    echo "✅ הרשאות superuser תוקנו"
else
    echo "✅ משתמש postgres כבר superuser"
fi
echo ""

# שלב 7: עדכון סיסמאות במסד נתונים
echo "🔐 שלב 7/8: מעדכן סיסמאות במסד הנתונים..."

# עדכן כל משתמש בנפרד כדי לוודא הצלחה
for user in postgres supabase_admin supabase_auth_admin supabase_storage_admin authenticator supabase_functions_admin supabase_replication_admin supabase_read_only_user; do
    docker exec supabase-db psql -h 127.0.0.1 -U postgres -d postgres -c "ALTER USER $user WITH PASSWORD '$NEW_POSTGRES_PASSWORD';" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✅ $user - סיסמה עודכנה"
    else
        echo "  ❌ $user - נכשל לעדכן סיסמה"
        exit 1
    fi
done

echo "✅ כל הסיסמאות במסד הנתונים עודכנו בהצלחה!"
echo ""

# וידוא שהסיסמאות עובדות
echo "🔍 מוודא שהסיסמאות עובדות..."
for user in postgres supabase_admin supabase_auth_admin authenticator supabase_storage_admin; do
    if docker exec -e PGPASSWORD="$NEW_POSTGRES_PASSWORD" supabase-db psql -h 127.0.0.1 -U $user -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
        echo "  ✅ $user - סיסמה עובדת"
    else
        echo "  ❌ $user - סיסמה לא עובדת!"
        echo "     מנסה שוב..."
        # נסה שוב לעדכן את הסיסמה
        docker exec supabase-db psql -h 127.0.0.1 -U postgres -d postgres -c "ALTER USER $user WITH PASSWORD '$NEW_POSTGRES_PASSWORD';" > /dev/null 2>&1
        sleep 2
        if docker exec -e PGPASSWORD="$NEW_POSTGRES_PASSWORD" supabase-db psql -h 127.0.0.1 -U $user -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
            echo "     ✅ $user - סיסמה עובדת אחרי ניסיון נוסף"
        else
            echo "     ❌ $user - עדיין לא עובד!"
            exit 1
        fi
    fi
done
echo ""

# עדכון קובץ .env - כתיבת ערכים לקובץ זמני ואז Python קורא אותם
echo "📝 מעדכן קובץ .env..."
cat > /tmp/tmp_values << EOF
POSTGRES_PASSWORD=$NEW_POSTGRES_PASSWORD
DASHBOARD_PASSWORD=$NEW_DASHBOARD_PASSWORD
PG_META_CRYPTO_KEY=$NEW_PG_META_CRYPTO_KEY
SECRET_KEY_BASE=$NEW_SECRET_KEY_BASE
VAULT_ENC_KEY=$NEW_VAULT_ENC_KEY
JWT_SECRET=$NEW_JWT_SECRET
ANON_KEY=$NEW_ANON_KEY
SERVICE_ROLE_KEY=$NEW_SERVICE_ROLE_KEY
EOF

python3 << 'PYEOF'
import re

# קרא ערכים מקובץ זמני
values = {}
with open('/tmp/tmp_values', 'r') as f:
    for line in f:
        if '=' in line:
            key, value = line.strip().split('=', 1)
            values[key] = value

# קרא את קובץ .env
with open('.env', 'r') as f:
    content = f.read()

# החלף ערכים
for key, value in values.items():
    pattern = f'^{key}=.*$'
    replacement = f'{key}={value}'
    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

# כתוב בחזרה
with open('.env', 'w') as f:
    f.write(content)
PYEOF

rm -f /tmp/tmp_values

echo "✅ קובץ .env עודכן"
echo ""

# שמירת סיסמאות בקובץ מאובטח
CREDS_FILE="/opt/supabase/CREDENTIALS-$TIMESTAMP.txt"
cat > $CREDS_FILE << CREDS
=== Supabase Credentials - $TIMESTAMP ===

POSTGRES_PASSWORD=$NEW_POSTGRES_PASSWORD
DASHBOARD_PASSWORD=$NEW_DASHBOARD_PASSWORD
PG_META_CRYPTO_KEY=$NEW_PG_META_CRYPTO_KEY
SECRET_KEY_BASE=$NEW_SECRET_KEY_BASE
VAULT_ENC_KEY=$NEW_VAULT_ENC_KEY
JWT_SECRET=$NEW_JWT_SECRET
ANON_KEY=$NEW_ANON_KEY
SERVICE_ROLE_KEY=$NEW_SERVICE_ROLE_KEY

=== Connection Info ===
PostgreSQL Direct: 100.66.73.12:5433
Database: postgres
User: postgres
Password: $NEW_POSTGRES_PASSWORD

Dashboard: http://100.66.73.12:8000
Username: admin
Password: $NEW_DASHBOARD_PASSWORD
CREDS

chmod 600 $CREDS_FILE
echo "✅ סיסמאות נשמרו ב-$CREDS_FILE (קובץ מאובטח)"
echo ""

# שלב 8: הפעלת כל השירותים
echo "🚀 שלב 8/8: מפעיל את כל השירותים (בלי analytics)..."
docker compose up -d --scale analytics=0

echo ""
echo "⏳ מחכה ששירותים יעלו (60 שניות)..."
sleep 60

echo ""
echo "📊 סטטוס שירותים:"
docker compose ps

echo ""
RESTARTING=$(docker compose ps | grep -i "restart" | wc -l)
UNHEALTHY=$(docker compose ps | grep -i "unhealthy" | wc -l)

if [ $RESTARTING -eq 0 ] && [ $UNHEALTHY -eq 0 ]; then
    echo "✅✅✅ הצלחה! כל השירותים פועלים תקין! ✅✅✅"
else
    echo "⚠️  יש $RESTARTING שירותים שנכשלים ו-$UNHEALTHY לא בריאים"
    echo ""
    echo "בודק אם צריך לתקן עוד סיסמאות..."

    # אם יש שירותים נכשלים, נסה לתקן
    if [ $RESTARTING -gt 0 ]; then
        echo "מפעיל מחדש שירותים נכשלים..."
        docker compose restart
        sleep 30
        echo ""
        echo "סטטוס לאחר הפעלה מחדש:"
        docker compose ps
    fi
fi

echo ""
echo "=== סיימתי! ==="
echo "קובץ סיסמאות: $CREDS_FILE"
echo ""
echo "פקודות שימושיות:"
echo "  סטטוס: cd /opt/supabase/supabase/docker && docker compose ps"
echo "  לוגים: cd /opt/supabase/supabase/docker && docker compose logs -f [service]"
echo "  הפעלה מחדש: cd /opt/supabase/supabase/docker && docker compose restart [service]"
