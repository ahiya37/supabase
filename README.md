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
│   └── nginx-setup.sh     # הגדרת Nginx ו-SSL
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
- דומיין המצביע לשרת
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
git clone https://github.com/YOUR_USERNAME/supabase.git
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
משתמש: admin
סיסמה: [ראה /opt/supabase/CREDENTIALS.txt]

# SSH חדש
ssh -i ~/.ssh/supabase-prod -p YOUR_PORT root@YOUR_SERVER_IP
```

### פקודות שימושיות

```bash
# עבור לתיקיית Supabase
cd /opt/supabase/supabase/docker

# בדיקת סטטוס
docker-compose ps

# צפייה בלוגים
docker-compose logs -f

# רסטארט
docker-compose restart
```

## 🛡️ אבטחה

הסקריפט מגדיר אוטומטית:

- SSH עם מפתחות בלבד
- חומת אש (UFW) עם פורטים נחוצים בלבד
- Fail2Ban להגנה מפני brute-force
- SSL/TLS עם Let's Encrypt
- סיסמאות אקראיות חזקות
- JWT tokens ייחודיים

## 🔨 תיקון Supavisor

הסקריפט כולל תיקון אוטומטי לבעיה הידועה של Supavisor:

- מסיר את ה-ports mapping מ-Supavisor
- מוסיף ports ל-DB על הפורט הנכון
- מוודא שאין קונפליקט בין השירותים

## 🌐 Tailscale (אופציונלי)

התקנה עם Tailscale מאפשרת:

- חיבור מאובטח ומוצפן לשרת מכל מקום
- VPN פרטי ללא צורך לחשוף פורטים נוספים
- ביצועים מעולים

להשגת Auth Key:
1. לך ל-https://login.tailscale.com/admin/settings/keys
2. צור מפתח חדש
3. הדבק בסקריפט ההתקנה

## 🐛 פתרון בעיות

### Dashboard לא נגיש

```bash
cd /opt/supabase/supabase/docker
docker-compose ps              # בדוק שהכל רץ
docker-compose logs kong       # בדוק לוגים
systemctl status nginx         # בדוק Nginx
```

### שכחתי סיסמה

```bash
cat /opt/supabase/CREDENTIALS.txt
```

### בעיות SSH

```bash
# ודא פורט נכון
ssh -i ~/.ssh/supabase-prod -p YOUR_PORT root@YOUR_SERVER_IP
```

לפרטים נוספים, ראה [docs/INSTALLATION.md](docs/INSTALLATION.md)

## 🤝 תרומה

תרומות מתקבלות בברכה! פתח issue או PR.

## 📝 רישיון

MIT License

## 👨‍💻 יוצר

נוצר עם ❤️ לקהילה

---

**הערה**: סקריפט זה מיועד לשרתים ייעודיים. אל תריץ על שרת פרודקשן קיים ללא גיבוי!
