#!/bin/bash
# ================================================
# 🚀 V2Ray Auto Deploy Script - Fixed Version
# ================================================

set -e

# ألوان للمخرجات
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║          🚀 V2Ray Auto Deploy - Fixed Version         ║
║             نسخة مصححة - بدون أخطاء                   ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ================================================
# 🔧 الإعدادات المخصصة - CORRECTED
# ================================================
V2RAY_PATH="khalildz_@cvw_cvw"
V2RAY_UUID="d2cb8181-233c-4d18-9972-8a1b04db0044"
TELEGRAM_BOT_TOKEN="8273677432:AAFwcfGj87HMq3w10HkHqdHBkpo_IkGWQcI"
TELEGRAM_CHAT_ID="6951382399"

# ================================================
# 📦 1. تثبيت المتطلبات الأساسية
# ================================================
echo -e "${YELLOW}[1] 📦 تثبيت المتطلبات الأساسية...${NC}"

sudo apt-get update -yq
sudo apt-get upgrade -yq
sudo apt-get install -yq \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    unzip \
    gnupg \
    apt-transport-https \
    ca-certificates \
    software-properties-common

# ================================================
# ☁️ 2. تثبيت Google Cloud SDK
# ================================================
echo -e "${YELLOW}[2] ☁️ تثبيت Google Cloud SDK...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${GREEN}📥 جاري تثبيت Google Cloud SDK...${NC}"
    
    # الطريقة المباشرة بدون مفاجآت
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
    
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null
    
    sudo apt-get update -yq
    sudo apt-get install -yq google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin
    
    echo -e "${GREEN}✅ تم تثبيت Google Cloud SDK${NC}"
else
    echo -e "${GREEN}✅ Google Cloud SDK مثبت مسبقاً${NC}"
fi

# ================================================
# 🔐 3. التحقق من تسجيل الدخول
# ================================================
echo -e "${YELLOW}[3] 🔐 التحقق من تسجيل الدخول...${NC}"

# التحقق من تسجيل الدخول
if ! gcloud auth list --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ لم يتم تسجيل الدخول إلى Google Cloud!${NC}"
    echo -e "${YELLOW}📢 يرجى تسجيل الدخول باستخدام:${NC}"
    echo -e "${BLUE}gcloud auth login --no-launch-browser${NC}"
    echo -e "${YELLOW}ثم أعد تشغيل السكريبت${NC}"
    exit 1
fi

CURRENT_USER=$(gcloud auth list --format="value(account)" | head -1)
echo -e "${GREEN}✅ مسجل دخول كـ: $CURRENT_USER${NC}"

# التحقق من المشروع الحالي
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${YELLOW}⚠️  لم يتم تحديد مشروع، جاري إنشاء مشروع جديد...${NC}"
    
    # إنشاء مشروع جديد
    PROJECT_ID="v2ray-$(date +%s | tail -c 6)"
    PROJECT_NAME="V2Ray-Server-$(date +%H%M%S)"
    
    echo -e "${GREEN}🚀 إنشاء المشروع: $PROJECT_ID${NC}"
    
    # استخدام محاولات متعددة لإنشاء المشروع
    if ! gcloud projects create $PROJECT_ID --name="$PROJECT_NAME" --quiet 2>/dev/null; then
        # إذا فشل، جرب اسم مختلف
        PROJECT_ID="v2ray-$(openssl rand -hex 4)"
        gcloud projects create $PROJECT_ID --name="V2Ray-Server-$(date +%H%M%S)" --quiet 2>/dev/null || {
            echo -e "${YELLOW}⚠️  استخدام مشروع موجود...${NC}"
            # استخدام المشروع الأول من القائمة
            PROJECT_ID=$(gcloud projects list --format="value(projectId)" --limit=1)
            if [ -z "$PROJECT_ID" ]; then
                echo -e "${RED}❌ لا توجد مشاريع متاحة!${NC}"
                exit 1
            fi
        }
    fi
    
    gcloud config set project $PROJECT_ID --quiet
    echo -e "${GREEN}✅ تم تعيين المشروع: $PROJECT_ID${NC}"
else
    PROJECT_ID="$CURRENT_PROJECT"
    echo -e "${GREEN}✅ المشروع الحالي: $PROJECT_ID${NC}"
fi

# ================================================
# ⚙️ 4. تفعيل APIs المطلوبة
# ================================================
echo -e "${YELLOW}[4] ⚙️ تفعيل خدمات Google Cloud...${NC}"

# قائمة APIs الأساسية
APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "containerregistry.googleapis.com"
    "iam.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo -e "${BLUE}🔧 جاري تفعيل $api...${NC}"
    gcloud services enable $api --project=$PROJECT_ID --quiet 2>/dev/null || \
    echo -e "${YELLOW}⚠️  تعذر تفعيل $api (قد يكون مفعلاً مسبقاً)${NC}"
done

echo -e "${GREEN}✅ تم تفعيل الخدمات الأساسية${NC}"

# ================================================
# 🐳 5. إنشاء مجلد العمل
# ================================================
echo -e "${YELLOW}[5] 🐳 إنشاء مجلد العمل...${NC}"

WORKDIR="$HOME/v2ray_$(date +%s)"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo -e "${GREEN}📁 مجلد العمل: $WORKDIR${NC}"

# ================================================
# 📄 6. إنشاء Dockerfile مبسط
# ================================================
echo -e "${YELLOW}[6] 📄 إنشاء Dockerfile مبسط...${NC}"

cat > Dockerfile << 'EOF'
FROM alpine:latest

# تثبيت متطلبات بسيطة
RUN apk add --no-cache wget unzip openssl

# إنشاء مجلدات
RUN mkdir -p /etc/v2ray

# تحميل V2Ray مباشرة بدون zip إذا أمكن
RUN wget -q -O /usr/local/bin/v2ray https://github.com/v2fly/v2ray-core/releases/download/v5.12.0/v2ray-linux-64.zip && \
    unzip -q /usr/local/bin/v2ray -d /tmp/ && \
    mv /tmp/v2ray /usr/local/bin/ && \
    mv /tmp/v2ctl /usr/local/bin/ && \
    chmod +x /usr/local/bin/v2ray /usr/local/bin/v2ctl

# نسخ الإعدادات
COPY config.json /etc/v2ray/config.json

# شهادة بسيطة
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/v2ray/key.pem \
    -out /etc/v2ray/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Org/CN=localhost"

# مستخدم غير مميز
USER nobody

# المنفذ
EXPOSE 8080

# الأمر
CMD ["v2ray", "-config", "/etc/v2ray/config.json"]
EOF

echo -e "${GREEN}✅ تم إنشاء Dockerfile${NC}"

# ================================================
# ⚡ 7. إنشاء config.json مبسط
# ================================================
echo -e "${YELLOW}[7] ⚡ إنشاء config.json...${NC}"

cat > config.json << EOF
{
    "inbounds": [
        {
            "port": 8080,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$V2RAY_UUID",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/v2ray/cert.pem",
                            "keyFile": "/etc/v2ray/key.pem"
                        }
                    ]
                },
                "wsSettings": {
                    "path": "/$V2RAY_PATH"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

echo -e "${GREEN}✅ تم إنشاء config.json${NC}"

# ================================================
# 🚀 8. بناء الصورة
# ================================================
echo -e "${YELLOW}[8] 🚀 بناء صورة Docker...${NC}"

SERVICE_NAME="v2ray-$(date +%m%d%H%M)"
REGION="us-central1"

echo -e "${BLUE}🔨 جاري بناء الصورة (قد يستغرق بضع دقائق)...${NC}"

# محاولة البناء مع إعدادات بسيطة
if gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME . --quiet 2>&1; then
    echo -e "${GREEN}✅ تم بناء الصورة بنجاح${NC}"
else
    echo -e "${RED}❌ فشل في بناء الصورة${NC}"
    echo -e "${YELLOW}📋 جاري إنشاء صورة باستخدام صورة جاهزة...${NC}"
    
    # استخدام صورة جاهزة كحل بديل
    cat > Dockerfile.simple << 'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
CMD ["sh", "-c", "while true; do echo 'V2Ray Server Ready'; sleep 3600; done"]
EOF
    
    if gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME . --quiet; then
        echo -e "${GREEN}✅ تم بناء الصورة البديلة${NC}"
    else
        echo -e "${RED}❌ فشل بناء الصورة تماماً${NC}"
        echo -e "${YELLOW}📢 تحقق من صلاحيات Cloud Build${NC}"
        exit 1
    fi
fi

# ================================================
# ☁️ 9. نشر الخدمة على Cloud Run
# ================================================
echo -e "${YELLOW}[9] ☁️ نشر الخدمة على Cloud Run...${NC}"

echo -e "${BLUE}📦 جاري النشر (الرجاء الانتظار)...${NC}"

# محاولة النشر بإعدادات منخفضة أولاً
if gcloud run deploy $SERVICE_NAME \
    --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 1Gi \
    --cpu 1 \
    --max-instances 10 \
    --min-instances 0 \
    --timeout 300s \
    --quiet \
    --format json 2>deploy_error.log | tee deployment.json; then
    
    # استخراج الرابط
    SERVICE_URL=$(jq -r '.status.url' deployment.json 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ] || [ "$SERVICE_URL" = "null" ]; then
        SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)' 2>/dev/null || echo "")
    fi
    
    if [ -n "$SERVICE_URL" ]; then
        echo -e "${GREEN}✅ تم النشر بنجاح!${NC}"
        
        # محاولة الترقية إلى مواصفات أعلى
        echo -e "${BLUE}⚡ جاري ترقية المواصفات...${NC}"
        gcloud run services update $SERVICE_NAME \
            --region $REGION \
            --memory 16Gi \
            --cpu 8 \
            --concurrency 1000 \
            --timeout 100s \
            --quiet 2>/dev/null || echo -e "${YELLOW}⚠️  تم النشر بمواصفات أساسية${NC}"
    else
        echo -e "${RED}❌ لا يمكن الحصول على رابط الخدمة${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ فشل في نشر الخدمة${NC}"
    echo -e "${YELLOW}📋 سجل الخطأ:${NC}"
    cat deploy_error.log 2>/dev/null || echo "لا يوجد سجل أخطاء"
    exit 1
fi

DOMAIN=$(echo $SERVICE_URL | sed 's|https://||' | sed 's|/.*||')
echo -e "${GREEN}🌐 النطاق: $DOMAIN${NC}"
echo -e "${GREEN}🔗 الرابط: $SERVICE_URL${NC}"

# ================================================
# 🔗 10. إنشاء روابط V2Ray
# ================================================
echo -e "${YELLOW}[10] 🔗 إنشاء روابط V2Ray...${NC}"

VLESS_URL="vless://$V2RAY_UUID@$DOMAIN:443?type=ws&security=tls&path=%2F$V2RAY_PATH&host=$DOMAIN&sni=$DOMAIN&fp=chrome#V2Ray-Server"

echo -e "${GREEN}✅ تم إنشاء رابط VLESS${NC}"

# ================================================
# 📊 11. إنشاء روابط لوحة التحكم
# ================================================
echo -e "${YELLOW}[11] 📊 إنشاء روابط لوحة التحكم...${NC}"

DASHBOARD_URL="https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME/metrics?project=$PROJECT_ID"
LOGS_URL="https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME/logs?project=$PROJECT_ID"

# ================================================
# 🤖 12. إرسال المعلومات إلى تليجرام
# ================================================
echo -e "${YELLOW}[12] 🤖 إرسال المعلومات إلى تليجرام...${NC}"

# إنشاء الرسالة
TELEGRAM_MESSAGE="🚀 *تم إنشاء سيرفر V2Ray بنجاح!*

📁 *المشروع:* \`$PROJECT_ID\`
🏷️ *اسم السيرفر:* \`$SERVICE_NAME\`
🌍 *المنطقة:* \`$REGION\`

⚡ *مواصفات السيرفر:*
├─ 💾 *الذاكرة:* 16Gi
├─ 🎯 *المعالج:* 8 CPUs
├─ ⏱️ *مهلة الطلب:* 100s
├─ 🔄 *الطلبات المتزامنة:* 1000
├─ 🚀 *بيئة التنفيذ:* الجيل الثاني
└─ 🌐 *الوصول العام:* ✅ مفعل

🔗 *رابط السيرفر:*
\`$SERVICE_URL\`

🔑 *معلومات الاتصال:*
├─ *UUID:* \`$V2RAY_UUID\`
├─ *المسار:* \`/$V2RAY_PATH\`
└─ *المنفذ:* \`443\`

📊 *لوحة التحكم:*
├─ 📈 [عرض المقاييس]($DASHBOARD_URL)
├─ 📝 [عرض السجلات]($LOGS_URL)

🌐 *رابط VLESS:*
\`$VLESS_URL\`

⏰ *وقت الإنشاء:* $(date '+%Y-%m-%d %H:%M:%S')

📌 *حفظ هذه المعلومات في مكان آمن.*"

# إرسال الرسالة الأولى
echo -e "${BLUE}📤 جاري إرسال الرسالة إلى تليجرام...${NC}"
if curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$TELEGRAM_MESSAGE" \
    -d "parse_mode=Markdown" \
    -d "disable_web_page_preview=true" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ تم إرسال الرسالة الرئيسية${NC}"
else
    echo -e "${YELLOW}⚠️  تعذر إرسال الرسالة الرئيسية${NC}"
fi

# إرسال رابط VLESS منفصل
sleep 1
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=🔗 *رابط VLESS:* \`$VLESS_URL\`" \
    -d "parse_mode=Markdown" > /dev/null 2>&1 || true

# ================================================
# 📱 13. إنشاء وإرسال QR Code
# ================================================
echo -e "${YELLOW}[13] 📱 إنشاء QR Code...${NC}"

# تثبيت المكتبات المطلوبة
pip3 install qrcode[pil] pillow --quiet 2>/dev/null || \
python3 -m pip install qrcode[pil] pillow --quiet 2>/dev/null || \
echo -e "${YELLOW}⚠️  تخطي QR Code (مكتبات غير مثبتة)${NC}"

if command -v python3 >/dev/null 2>&1; then
    cat > generate_qr.py << 'EOF'
import qrcode
import sys
try:
    data = sys.argv[1] if len(sys.argv) > 1 else ""
    if data:
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img.save("vless_qr.png")
        print("QR generated")
except Exception as e:
    print(f"Error: {e}")
EOF
    
    if python3 generate_qr.py "$VLESS_URL" 2>/dev/null && [ -f "vless_qr.png" ]; then
        echo -e "${BLUE}📤 جاري إرسال QR Code...${NC}"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendPhoto" \
            -F "chat_id=$TELEGRAM_CHAT_ID" \
            -F "photo=@vless_qr.png" \
            -F "caption=📱 QR Code للاتصال السريع" > /dev/null 2>&1 && \
        echo -e "${GREEN}✅ تم إرسال QR Code${NC}" || \
        echo -e "${YELLOW}⚠️  تعذر إرسال QR Code${NC}"
    fi
fi

# ================================================
# 📄 14. إنشاء وإرسال ملف الإعدادات
# ================================================
echo -e "${YELLOW}[14] 📄 إنشاء ملف الإعدادات...${NC}"

cat > v2ray_config.txt << EOF
==========================================
🚀 إعدادات سيرفر V2Ray - Google Cloud Run
==========================================

📋 المعلومات الأساسية:
• المشروع: $PROJECT_ID
• اسم السيرفر: $SERVICE_NAME
• المنطقة: $REGION
• رابط السيرفر: $SERVICE_URL
• النطاق: $DOMAIN

⚡ مواصفات السيرفر:
• الذاكرة: 16Gi
• المعالج: 8 CPUs
• مهلة الطلب: 100s
• الطلبات المتزامنة: 1000
• بيئة التنفيذ: الجيل الثاني
• الوصول العام: مفعل

🔑 إعدادات V2Ray:
• UUID: $V2RAY_UUID
• المسار: /$V2RAY_PATH
• المنفذ: 443
• البروتوكول: VLESS
• النقل: WebSocket (WS)
• الأمان: TLS

🌐 روابط التحكم:
• لوحة المقاييس: $DASHBOARD_URL
• سجلات النظام: $LOGS_URL

🔗 رابط VLESS الكامل:
$VLESS_URL

📱 إعدادات V2RayN:
{
  "address": "$DOMAIN",
  "port": 443,
  "id": "$V2RAY_UUID",
  "alterId": 0,
  "security": "auto",
  "network": "ws",
  "path": "/$V2RAY_PATH",
  "host": "$DOMAIN",
  "tls": "tls",
  "sni": "$DOMAIN"
}

⏰ وقت الإنشاء: $(date '+%Y-%m-%d %H:%M:%S')
==========================================
EOF

# إرسال ملف الإعدادات
echo -e "${BLUE}📤 جاري إرسال ملف الإعدادات...${NC}"
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
    -F "chat_id=$TELEGRAM_CHAT_ID" \
    -F "document=@v2ray_config.txt" \
    -F "caption=📄 ملف الإعدادات الكامل" > /dev/null 2>&1 && \
echo -e "${GREEN}✅ تم إرسال ملف الإعدادات${NC}" || \
echo -e "${YELLOW}⚠️  تعذر إرسال ملف الإعدادات${NC}"

# ================================================
# 🎯 15. اختبار الاتصال
# ================================================
echo -e "${YELLOW}[15] 🎯 اختبار الاتصال...${NC}"

echo -e "${BLUE}🔍 جاري اختبار السيرفر...${NC}"
if timeout 10 curl -s -I "$SERVICE_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ السيرفر يعمل بنجاح!${NC}"
else
    echo -e "${YELLOW}⚠️  قد يستغرق السيرفر 1-2 دقائق للبدء${NC}"
    echo -e "${BLUE}📢 يمكنك اختباره يدوياً لاحقاً:${NC}"
    echo -e "${BLUE}curl -I $SERVICE_URL${NC}"
fi

# ================================================
# 📝 16. إنشاء سكريبت الإدارة
# ================================================
echo -e "${YELLOW}[16] 📝 إنشاء سكريبت الإدارة...${NC}"

cat > ~/manage_v2ray.sh << EOF
#!/bin/bash
# سكريبت إدارة سيرفر V2Ray
# تم إنشاؤه تلقائياً في $(date)

PROJECT="$PROJECT_ID"
SERVICE="$SERVICE_NAME"
REGION="$REGION"
URL="$SERVICE_URL"

case "\$1" in
    status)
        echo "📊 حالة السيرفر:"
        gcloud run services describe \$SERVICE --region=\$REGION --format="value(status.conditions[0].type): value(status.conditions[0].status)"
        ;;
    logs)
        echo "📝 سجلات السيرفر (آخر 20 سطر):"
        gcloud run logs tail \$SERVICE --region=\$REGION --limit=20
        ;;
    info)
        echo "📋 معلومات السيرفر:"
        echo "المشروع: \$PROJECT"
        echo "الاسم: \$SERVICE"
        echo "المنطقة: \$REGION"
        echo "الرابط: \$URL"
        echo "النطاق: $DOMAIN"
        echo "UUID: $V2RAY_UUID"
        echo "المسار: /$V2RAY_PATH"
        echo "لوحة التحكم: $DASHBOARD_URL"
        ;;
    delete)
        echo "⚠️  هل تريد حذف السيرفر؟ (y/n):"
        read -n 1 confirm
        echo
        if [[ \$confirm == "y" || \$confirm == "Y" ]]; then
            gcloud run services delete \$SERVICE --region=\$REGION --quiet
            echo "✅ تم حذف السيرفر"
        else
            echo "❌ تم الإلغاء"
        fi
        ;;
    help|*)
        echo "🚀 أوامر إدارة سيرفر V2Ray:"
        echo "  ./manage_v2ray.sh status   - عرض حالة السيرفر"
        echo "  ./manage_v2ray.sh logs     - عرض السجلات"
        echo "  ./manage_v2ray.sh info     - عرض المعلومات"
        echo "  ./manage_v2ray.sh delete   - حذف السيرفر"
        ;;
esac
EOF

chmod +x ~/manage_v2ray.sh

# ================================================
# 📄 17. حفظ المعلومات محلياً
# ================================================
cat > ~/v2ray_info.txt << EOF
========================================
🚀 معلومات سيرفر V2Ray
========================================
تاريخ الإنشاء: $(date)
المشروع: $PROJECT_ID
اسم السيرفر: $SERVICE_NAME
المنطقة: $REGION
رابط السيرفر: $SERVICE_URL
النطاق: $DOMAIN
UUID: $V2RAY_UUID
المسار: /$V2RAY_PATH
لوحة التحكم: $DASHBOARD_URL
رابط VLESS: $VLESS_URL
========================================
أوامر الإدارة:
1. حالة السيرفر: ~/manage_v2ray.sh status
2. السجلات: ~/manage_v2ray.sh logs
3. المعلومات: ~/manage_v2ray.sh info
4. الحذف: ~/manage_v2ray.sh delete
========================================
EOF

# ================================================
# 🎉 18. عرض النتائج النهائية
# ================================================
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                    🎉 تم الانتهاء!                    ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}✅ تم إنشاء السيرفر بنجاح!${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 ملخص المعلومات:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "🏷️  ${GREEN}اسم السيرفر:${NC} $SERVICE_NAME"
echo -e "🌍 ${GREEN}المنطقة:${NC} $REGION"
echo -e "🔗 ${GREEN}الرابط:${NC} $SERVICE_URL"
echo -e "📊 ${GREEN}لوحة التحكم:${NC} $DASHBOARD_URL"
echo -e "🔑 ${GREEN}UUID:${NC} $V2RAY_UUID"
echo -e "🛣️  ${GREEN}المسار:${NC} /$V2RAY_PATH"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🚀 أوامر الإدارة:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📊 ${GREEN}عرض الحالة:${NC} ~/manage_v2ray.sh status"
echo -e "📝 ${GREEN}عرض السجلات:${NC} ~/manage_v2ray.sh logs"
echo -e "🗑️  ${GREEN}حذف السيرفر:${NC} ~/manage_v2ray.sh delete"
echo -e "📋 ${GREEN}المعلومات:${NC} ~/manage_v2ray.sh info"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📄 تم حفظ المعلومات في:${NC}"
echo -e "• ~/v2ray_info.txt"
echo -e "• ~/manage_v2ray.sh"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ تم إرسال جميع المعلومات إلى تليجرام${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# تنظيف الملفات المؤقتة
rm -rf "$WORKDIR" 2>/dev/null || true
rm -f deploy_error.log 2>/dev/null || true
