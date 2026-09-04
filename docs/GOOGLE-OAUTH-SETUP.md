# Google OAuth setup — اپنی credentials بنائیں

FarooqDrive کی public repository میں کسی کی ذاتی key شامل نہیں۔ ہر builder یا
deployer اپنا Google Cloud project اور OAuth client خود بنائے گا۔

## مشترک ابتدائی steps

1. [Google Cloud Console](https://console.cloud.google.com/) کھولیں۔
2. نیا project بنائیں، مثلاً `My FarooqDrive`۔
3. **APIs & Services > Library** میں **Google Drive API** enable کریں۔
4. **Google Auth Platform** میں app name، support email اور developer email دیں۔
5. Audience منتخب کریں۔ Testing mode میں استعمال ہونے والے تمام Google accounts
   کو **Test users** میں شامل کریں۔
6. Data Access/Scopes میں OpenID, email, profile اور
   `https://www.googleapis.com/auth/drive` شامل کریں۔

Full Drive scope حساس/restricted ہو سکتا ہے۔ صرف ذاتی Testing mode کے لیے test
users کافی ہیں؛ public production app کے لیے Google verification، واضح privacy
policy، domain verification اور ممکنہ security assessment درکار ہو سکتے ہیں۔

## Windows Desktop Client

1. **Clients > Create client > Desktop app** منتخب کریں۔
2. بننے والا Client ID اور Client Secret صرف اپنی Windows app کی پہلی setup
   screen میں درج کریں۔
3. انہیں repository، screenshot، issue یا chat میں کبھی شامل نہ کریں۔
4. Desktop OAuth loopback callback خود app عارضی localhost port پر سنبھالتی ہے۔

## Web Client

1. **Clients > Create client > Web application** منتخب کریں۔
2. **Authorized JavaScript origins** میں اپنی اصل HTTPS site شامل کریں، مثال:
   `https://drive.example.com`۔
3. Local test کے لیے صرف ضرورت کے مطابق `http://localhost:PORT` شامل کریں۔
4. Web page کے Settings میں صرف **Client ID** درج کریں۔
5. Web app میں Client Secret کبھی استعمال نہ کریں—browser اسے محفوظ نہیں رکھ سکتا۔

## Publish کرنے سے پہلے

- Authorized domain Google Auth Platform میں verify کریں۔
- Privacy Policy اور Terms اسی verified domain پر شائع کریں۔
- OAuth consent screen کے links درست کریں۔
- Test users کے ساتھ login، logout، token expiry اور revoke flow آزمائیں۔
- اگر Google verification مانگے تو app کو verification مکمل ہونے تک Testing میں رکھیں۔
