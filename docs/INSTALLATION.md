# מדריך התקנה - Supabase

## תוכן עניינים

- [דרישות מקדימות](#דרישות-מקדימות)
- [התקנה מהירה](#התקנה-מהירה)
- [הכנה לפני ההתקנה](#הכנה-לפני-ההתקנה)
- [תהליך ההתקנה](#תהליך-ההתקנה)
- [אחרי ההתקנה](#אחרי-ההתקנה)
- [פתרון בעיות](#פתרון-בעיות)

---

## דרישות מקדימות

### שרת

- מערכת הפעלה: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- זיכרון RAM: מינימום 4GB (מומלץ 8GB+)
- מעבד: מינימום 2 ליבות (מומלץ 4+)
- שטח דיסק: מינימום 20GB פנויים
- גישת root לשרת

### רשת

- דומיין עם רשומת A המצביעה לכתובת IP של השרת
- פורטים פתוחים:
  - 22 (או פורט SSH מותאם אישית)
  - 80 (HTTP)
  - 443 (HTTPS)
  - 5432 (PostgreSQL - אופציונלי)

### כלים במחשב המקומי שלך

- Terminal (Linux/Mac) או PowerShell/WSL (Windows)
- SSH client

---

## התקנה מהירה

```bash
# הורד את הפרוייקט
git clone https://github.com/YOUR_USERNAME/supabase-installer.git
cd supabase-installer

# הרץ את סקריפט ההתקנה
sudo bash install.sh
```

---

## הכנה לפני ההתקנה

### 1. יצירת מפתח SSH

במחשב המקומי שלך, פתח terminal והרץ:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/supabase-prod -C "your@email.com"
```

לחץ Enter פעמיים (ללא passphrase).

### 2. הצגת המפתח הציבורי

```bash
cat ~/.ssh/supabase-prod.pub
```

העתק את כל התוכן (מתחיל ב-`ssh-ed25519...`).

### 3. הכנת פרטים נוספים

לפני שמתחילים את ההתקנה, הכן:

- ✅ דומיין (לדוגמה: `supabase.example.com`)
- ✅ כתובת אימייל (לתעודת SSL)
- ✅ מפתח Tailscale (אופציונלי - אם רוצים VPN פרטי)

---

## תהליך ההתקנה

### שלב 1: התחברות לשרת

```bash
ssh root@YOUR_SERVER_IP
```

### שלב 2: הורדת הסקריפט

```bash
git clone https://github.com/YOUR_USERNAME/supabase-installer.git
cd supabase-installer
```

### שלב 3: הרצת ההתקנה

```bash
sudo bash install.sh
```

### שלב 4: מענה לשאלות

הסקריפט ישאל אותך מספר שאלות:

1. **האם יצרת מפתח SSH?** - ענה `y`
2. **שם המפתח** - לדוגמה: `supabase-prod`
3. **המפתח הציבורי** - הדבק את המפתח שהעתקת
4. **דומיין** - לדוגמה: `supabase.example.com`
5. **אימייל** - לדוגמה: `admin@example.com`
6. **תיקיית התקנה** - Enter לברירת מחדל (`/opt/supabase`)
7. **פורט SSH** - Enter לברירת מחדל (22) או פורט מותאם אישית
8. **פורט PostgreSQL** - Enter לברירת מחדל (5432)
9. **התקנת Tailscale?** - `y` או `n`

### שלב 5: המתן להתקנה

ההתקנה אורכת בין 10-20 דקות, תלוי במהירות האינטרנט ובמשאבי השרת.

---

## אחרי ההתקנה

### גישה למערכת

1. **Dashboard**:
   ```
   https://your-domain.com
   משתמש: admin
   סיסמה: [נשמר בקובץ CREDENTIALS.txt]
   ```

2. **SSH חדש**:
   ```bash
   ssh -i ~/.ssh/supabase-prod -p YOUR_SSH_PORT root@YOUR_SERVER_IP
   ```

### קבצים חשובים

- **פרטי גישה**: `/opt/supabase/CREDENTIALS.txt`
- **הגדרות Supabase**: `/opt/supabase/supabase/docker/.env`
- **Docker Compose**: `/opt/supabase/supabase/docker/docker-compose.yml`

### פקודות שימושיות

```bash
# עבור לתיקיית Supabase
cd /opt/supabase/supabase/docker

# בדיקת סטטוס
docker-compose ps

# צפייה בלוגים
docker-compose logs -f

# רסטארט שירות מסוים
docker-compose restart kong

# רסטארט כל השירותים
docker-compose restart

# עצירת המערכת
docker-compose down

# הפעלת המערכת
docker-compose up -d
```

---

## פתרון בעיות

### בעיה: לא מצליח להתחבר ב-SSH לאחר ההתקנה

**פתרון**:
```bash
# ודא שאתה משתמש בפורט הנכון ובמפתח הנכון
ssh -i ~/.ssh/supabase-prod -p YOUR_SSH_PORT root@YOUR_SERVER_IP

# אם שכחת את הפורט, חבר מהחלון הישן שעדיין פתוח ובדוק:
grep "^Port" /etc/ssh/sshd_config
```

### בעיה: Dashboard לא נגיש

**בדיקות**:

1. בדוק שכל השירותים רצים:
   ```bash
   cd /opt/supabase/supabase/docker
   docker-compose ps
   ```

2. בדוק את הלוגים של Kong:
   ```bash
   docker-compose logs kong
   ```

3. בדוק שNginx רץ:
   ```bash
   systemctl status nginx
   ```

### בעיה: שגיאת SSL

**פתרון**:

אם תעודת SSL נכשלה, המערכת התקינה במצב HTTP. ניתן לקבל SSL מאוחר יותר:

```bash
# עצור Nginx
systemctl stop nginx

# קבל תעודה
certbot certonly --standalone -d your-domain.com

# ערוך את Nginx להשתמש ב-SSL
nano /etc/nginx/sites-available/supabase

# הפעל Nginx
systemctl start nginx
```

### בעיה: שירות מסוים לא רץ

**פתרון**:

```bash
cd /opt/supabase/supabase/docker

# רסטארט לשירות הספציפי
docker-compose restart SERVICE_NAME

# לדוגמה:
docker-compose restart storage
docker-compose restart kong
```

### בעיה: שכחתי את הסיסמאות

**פתרון**:

כל הסיסמאות והמפתחות שמורים בקובץ:
```bash
cat /opt/supabase/CREDENTIALS.txt
```

---

## תיקון Supavisor

הסקריפט כולל תיקון אוטומטי לבעיה הידועה של Supavisor שמנסה לתפוס את פורט 5432 במקום ה-DB.

התיקון:
- ✅ מסיר את ה-ports mapping מ-Supavisor
- ✅ מוסיף ports ל-DB על הפורט הנכון
- ✅ מוודא שאין קונפליקט בין השירותים

---

## Tailscale (VPN פרטי)

אם התקנת Tailscale, תוכל להתחבר לשרת דרך ה-VPN הפרטי שלך:

```bash
# חיבור SSH דרך Tailscale
ssh -i ~/.ssh/supabase-prod -p YOUR_SSH_PORT root@TAILSCALE_IP

# חיבור למסד נתונים דרך Tailscale
psql -h TAILSCALE_IP -p 5432 -U postgres -d postgres
```

היתרונות:
- 🔒 חיבור מוצפן מכל מקום
- 🚫 אין צורך לחשוף פורטים נוספים באינטרנט
- ⚡ ביצועים מעולים

---

## אבטחה

### מה הסקריפט מגדיר אוטומטית:

- ✅ SSH עם מפתח בלבד (סיסמאות מושבתות)
- ✅ UFW (חומת אש)
- ✅ Fail2Ban (הגנה מפני התקפות brute-force)
- ✅ SSL/TLS (תעודת Let's Encrypt)
- ✅ סיסמאות חזקות אקראיות
- ✅ JWT tokens ייחודיים

### המלצות נוספות:

1. **גיבויים קבועים**:
   ```bash
   # גיבוי מסד הנתונים
   docker exec supabase-db pg_dump -U postgres postgres > backup.sql
   ```

2. **עדכוני אבטחה**:
   ```bash
   apt update && apt upgrade -y
   ```

3. **ניטור לוגים**:
   ```bash
   # SSH
   tail -f /var/log/auth.log

   # Nginx
   tail -f /var/log/nginx/error.log
   ```

---

## תמיכה

אם נתקלת בבעיות:

1. בדוק את הלוגים של Docker: `docker-compose logs -f`
2. בדוק את לוגי המערכת: `journalctl -xe`
3. פתח issue ב-GitHub

---

## רישיון

MIT License - ראה קובץ LICENSE לפרטים.
