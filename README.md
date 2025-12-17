# 🚀 Supabase Installation Script

סקריפט התקנה מקיף ומאובטח למערכת Supabase עם תיקון אוטומטי לבעיות ידועות.

## ✨ תכונות

- ✅ **התקנה אוטומטית מלאה** של Supabase על שרת ייעודי
- ✅ **תיקון אוטומטי** לבעיית Supavisor (קונפליקט בפורט 5432)
- ✅ **אבטחה מקסימלית**:
  - SSH עם מפתחות בלבד (סיסמאות מושבתות)
  - חומת אש (UFW)
  - הגנה מפני brute-force (Fail2Ban)
  - SSL/TLS אוטומטי עם Let's Encrypt
- ✅ **יצירת סיסמאות חזקות** אוטומטית
- ✅ **JWT tokens ייחודיים** לכל שרת
- ✅ **סקריפט החלפת סיסמאות** אוטומטי ומאובטח
- ✅ **תמיכה ב-Tailscale** (VPN פרטי אופציונלי)
- ✅ **קבצי תצורה מסודרים** ונפרדים
- ✅ **תיעוד מלא בעברית**

## 📁 מבנה הפרוייקט

```
supabase/
├── install.sh              # סקריפט התקנה ראשי
├── scripts/                # סקריפטים מודולריים
│   ├── utils.sh           # פונקציות עזר (צבעים, הדפסה, וכו')
│   ├── docker-setup.sh    # התקנת Docker ו-Docker Compose
│   ├── security-setup.sh  # הגדרות אבטחה (SSH, UFW, Fail2Ban)
│   ├── nginx-setup.sh     # הגדרת Nginx ו-SSL
│   └── rotate-passwords.sh # סקריפט להחלפת סיסמאות אוטומטי
├── config/                 # קבצי תצורה
│   ├── nginx-ssl.conf     # תבנית Nginx עם SSL
│   ├── nginx-http.conf    # תבנית Nginx ללא SSL
│   └── fail2ban.conf      # תבנית Fail2Ban
├── docs/                   # תיעוד
│   └── INSTALLATION.md    # מדריך התקנה מפורט
└── README.md              # קובץ זה
```

## 🚀 התקנה מהירה

### דרישות מקדימות

- שרת Ubuntu/Debian/CentOS עם גישת root
- מינימום 4GB RAM (מומלץ 8GB+)
- דומיין המצביע לשרת (אופציונלי - לSSL)
- מפתח SSH (ראה הוראות למטה)

### יצירת מפתח SSH (במחשב המקומי)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/supabase-prod -C "your@email.com"
cat ~/.ssh/supabase-prod.pub  # העתק את התוכן
```

### הרצת ההתקנה (בשרת)

```bash
# התחבר לשרת
ssh root@YOUR_SERVER_IP

# הורד את הפרוייקט
git clone https://github.com/achiya-automation/supabase.git
cd supabase

# הרץ את ההתקנה
sudo bash install.sh
```

## 📚 תיעוד מלא

למדריך התקנה מפורט, ראה [docs/INSTALLATION.md](docs/INSTALLATION.md)

## 🔧 שימוש לאחר ההתקנה

### גישה למערכת

```bash
# Dashboard
https://your-domain.com
משתמש: supabase
סיסמה: [ראה /opt/supabase/CREDENTIALS-*.txt]

# PostgreSQL Direct
Host: YOUR_SERVER_IP
Port: 5433
Database: postgres
User: postgres
Password: [ראה /opt/supabase/CREDENTIALS-*.txt]

# SSH חדש (אם שינית פורט)
ssh -i ~/.ssh/supabase-prod -p 2222 root@YOUR_SERVER_IP
```

### פקודות שימושיות

```bash
# עבור לתיקיית Supabase
cd /opt/supabase/supabase/docker

# בדיקת סטטוס
docker compose ps

# צפייה בלוגים
docker compose logs -f

# צפייה בלוגים של שירות ספציפי
docker compose logs -f auth

# רסטארט
docker compose restart

# רסטארט שירות ספציפי
docker compose restart auth
```

## 🔐 החלפת סיסמאות

הסקריפט כולל כלי אוטומטי להחלפת כל הסיסמאות והסודות במערכת:

### מתי להשתמש?

- אחרי התקנה ראשונה (אופציונלי - להחלפת הסיסמאות שנוצרו)
- אחרי שסיסמאות נחשפו בטעות
- כחלק מתהליך אבטחה תקופתי
- אחרי ש-Claude או כלי אוטומציה אחר ראה את הסיסמאות

### איך להריץ?

```bash
# התחבר לשרת
ssh -p 2222 root@YOUR_SERVER_IP

# הרץ את סקריפט החלפת הסיסמאות
bash /opt/supabase/scripts/rotate-passwords.sh
```

### מה הסקריפט עושה?

1. ✅ **יוצר גיבוי** של קובץ .env הנוכחי
2. ✅ **מייצר סיסמאות חדשות** חזקות (32-64 תווים)
3. ✅ **יוצר JWT tokens חדשים** (ANON_KEY, SERVICE_ROLE_KEY)
4. ✅ **מעדכן את מסד הנתונים** - משנה סיסמאות לכל 8 המשתמשים
5. ✅ **בודק שהסיסמאות עובדות** לפני המשך
6. ✅ **מעדכן את קובץ .env** עם הסיסמאות החדשות
7. ✅ **שומר את הסיסמאות** בקובץ מאובטח עם הרשאות 600
8. ✅ **מפעיל מחדש את כל השירותים** ובודק שהכל פועל

### הסיסמאות החדשות

הסיסמאות החדשות נשמרות בקובץ מאובטח:

```bash
# צפה בסיסמאות החדשות
cat /opt/supabase/CREDENTIALS-*.txt | tail -50

# או רק את האחרון
ls -lt /opt/supabase/CREDENTIALS-*.txt | head -1
cat $(ls -t /opt/supabase/CREDENTIALS-*.txt | head -1)
```

**חשוב:** אחרי הרצת הסקריפט, עדכן את הסיסמאות בכל המקומות שמשתמשים בהן (n8n, אפליקציות, וכו').

## 🛡️ אבטחה

הסקריפט מגדיר אוטומטית:

- SSH עם מפתחות בלבד (פורט 2222)
- חומת אש (UFW) עם פורטים נחוצים בלבד:
  - 2222: SSH
  - 80: HTTP
  - 443: HTTPS
  - 5433: PostgreSQL (חסום בחומת אש - נגיש רק דרך Tailscale)
- Fail2Ban להגנה מפני brute-force
- SSL/TLS עם Let's Encrypt (אופציונלי)
- סיסמאות אקראיות חזקות (32-64 תווים)
- JWT tokens ייחודיים לכל שרת
- PostgreSQL נגיש רק דרך Tailscale VPN

## 🔨 תיקון Supavisor

הסקריפט כולל תיקון אוטומטי לבעיה הידועה של Supavisor:

- מסיר את ה-ports mapping מ-Supavisor (מונע קונפליקט)
- מוסיף ports ל-DB על פורט 5433
- מוודא שאין קונפליקט בין השירותים
- PostgreSQL נגיש ישירות על פורט 5433

## 🌐 Tailscale (מומלץ מאוד!)

התקנה עם Tailscale מאפשרת:

- חיבור מאובטח ומוצפן לשרת מכל מקום
- VPN פרטי ללא צורך לחשוף פורטים נוספים
- גישה מאובטחת ל-PostgreSQL על פורט 5433
- ביצועים מעולים

### התקנת Tailscale

```bash
# הורד והתקן
curl -fsSL https://tailscale.com/install.sh | sh

# התחבר לרשת שלך
sudo tailscale up --auth-key=YOUR_AUTH_KEY
```

להשגת Auth Key:
1. לך ל-https://login.tailscale.com/admin/settings/keys
2. צור מפתח חדש (Auth key)
3. הדבק בפקודה למעלה

### חיבור ל-PostgreSQL דרך Tailscale

```bash
# קבל את כתובת ה-IP של Tailscale בשרת
tailscale ip -4

# השתמש בכתובת הזו להתחברות
psql -h 100.x.x.x -p 5433 -U postgres -d postgres
```

## 🐛 פתרון בעיות

### Dashboard לא נגיש

```bash
cd /opt/supabase/supabase/docker
docker compose ps              # בדוק שהכל רץ
docker compose logs kong       # בדוק לוגים של API Gateway
docker compose logs studio     # בדוק לוגים של Dashboard
systemctl status nginx         # בדוק Nginx (אם התקנת)
```

### שירות נכשל

```bash
# בדוק לוגים של השירות
docker compose logs auth       # לדוגמה: auth

# רסטארט לשירות ספציפי
docker compose restart auth

# רסטארט לכל המערכת
docker compose restart
```

### שכחתי סיסמה

```bash
# צפה בקובץ סיסמאות האחרון
cat $(ls -t /opt/supabase/CREDENTIALS-*.txt | head -1)

# או כל קבצי הסיסמאות
ls -lt /opt/supabase/CREDENTIALS-*.txt
```

### לא מצליח להתחבר ל-PostgreSQL

```bash
# ודא שהפורט פתוח
docker compose ps | grep db

# בדוק שהסיסמה נכונה
grep POSTGRES_PASSWORD /opt/supabase/supabase/docker/.env

# נסה להתחבר מהשרת עצמו
docker exec -it supabase-db psql -U postgres -d postgres
```

### בעיות SSH

```bash
# ודא פורט נכון (2222 אם שינית)
ssh -i ~/.ssh/supabase-prod -p 2222 root@YOUR_SERVER_IP

# אם נעלת, התחבר דרך הקונסול של ספק השרת
```

לפרטים נוספים, ראה [docs/INSTALLATION.md](docs/INSTALLATION.md)

## 📊 ניטור ותחזוקה

### בדיקת בריאות המערכת

```bash
# סטטוס כל השירותים
docker compose ps

# שימוש במשאבים
docker stats

# שימוש בדיסק
df -h
du -sh /opt/supabase/*
```

### גיבוי

```bash
# גיבוי מסד הנתונים
docker exec supabase-db pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# גיבוי קבצי תצורה
tar -czf config_backup_$(date +%Y%m%d).tar.gz /opt/supabase/supabase/docker/.env*
```

### עדכונים

```bash
cd /opt/supabase/supabase/docker

# שמור תצורה נוכחית
cp .env .env.backup

# עדכן images
docker compose pull

# הפעל מחדש עם גרסאות חדשות
docker compose up -d
```

## 🤝 תרומה

תרומות מתקבלות בברכה! פתח issue או PR.

## 📝 רישיון

MIT License

## 👨‍💻 יוצר

נוצר עם ❤️ על ידי [Achiya Automation](https://github.com/achiya-automation)

---

**הערה חשובה**: סקריפט זה מיועד לשרתים ייעודיים. אל תריץ על שרת פרודקשן קיים ללא גיבוי!

**אבטחה**: אחרי התקנה, מומלץ להריץ את סקריפט החלפת הסיסמאות כדי להחליף את הסיסמאות שנוצרו בהתקנה.
