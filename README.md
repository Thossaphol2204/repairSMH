# Repair Management App

แอปพลิเคชันจัดการงานซ่อมบำรุงและ PM (Preventive Maintenance) สำหรับโรงงานอุตสาหกรรม

โครงสร้างโปรเจคเบื้องต้น
[slide](https://www.canva.com/design/DAGrdkjFSbs/Pt-YGtQr1K8ie3PrIzegTw/edit)
## 🚀 คุณสมบัติหลัก

- **แจ้งซ่อม** : ระบบแจ้งซ่อมเครื่องจักร
- **ประเมิน** : ระบบประเมินผลการซ่อมจากลูกค้า
- **งานช่าง** : ระบบบันทึกรายงานงานช่าง
- **PM** : ระบบจัดการ Preventive Maintenance
- **สรุปการซ่อม** : รายงานสรุปการซ่อม
- **สรุป PM** : รายงานสรุป PM

## 📁 โครงสร้างโปรเจค

```
lib/
├── main.dart                  
├── constants.dart             
├── screens/                  
│   ├── about_screen.dart
│   ├── bug_report_screen.dart
│   ├── role_selection_screen.dart
│   ├── work_order_overview_screen.dart
├── tabs/                     
│   ├── repair_tab.dart
│   ├── customer_feedback_tab.dart
│   ├── work_order_tab.dart
│   ├── pm_tab.dart
│   ├── repair_summary_tab.dart
│   ├── pm_summary_tab.dart
│   └── work_report_tab.dart
├── pm_page/                
│   ├── pm_zone_widget.dart
│   ├── zone1.dart
│   ├── zone2.dart
│   ├── zone3.dart
│   ├── zone4.dart
│   └── zone5.dart
assets/
└── icon/                     
    └── logo_SMH.png
```
## 🛠️ วิธีติดตั้งและรันโปรเจกต์

### 1. ติดตั้ง Flutter SDK
- ดาวน์โหลดและติดตั้ง Flutter ตามคู่มือ [Flutter Install](https://docs.flutter.dev/get-started/install)
- ตรวจสอบว่าเครื่องมี git และ dart ด้วย (Flutter จะติดตั้ง Dart ให้อัตโนมัติ)

### 2. Clone โปรเจกต์จาก GitHub
```sh
 git clone https://github.com/Thossaphol2204/repairSMH.git
 cd repair-app
```

### 3. ติดตั้ง dependencies
```sh
flutter pub get
```

### 4. รันแอปบน Emulator หรือ Device จริง
```sh
flutter run
```
- ถ้าเจอ error device ไม่เจอ ให้รัน `flutter devices` หรือเปิด emulator ก่อน

### 5. Troubleshooting เบื้องต้น
- ถ้าเจอ error ให้รัน `flutter doctor` เพื่อตรวจสอบสภาพแวดล้อม
- ถ้า build ไม่ผ่าน ลองรัน `flutter clean` แล้ว `flutter pub get` ใหม่
- ถ้า clone มาแล้วรันไม่ได้ ให้เช็คว่าใช้ Flutter เวอร์ชันตรงกับใน `pubspec.yaml` (เช่น sdk: ^3.7.2)

---
## 📱 เทคโนโลยีที่ใช้

- **Flutter**: UI Framework
- **Dart**: Programming Language
- **HTTP**: API Communication
- **SharedPreferences**: Local Storage
- **Google Apps Script**: [Backend API](https://drive.google.com/drive/folders/1mMsXylghW1H_1xkqm7W_BPS6UtSj-y4P?usp=sharing)

## 📄 License

MIT License

## 📄 License
พาร์ทที่ต้องเพิ่มเติมในโปรเจคเบื้องต้น
- ระบบ Login (หรือไม่ก็ได้หากใช้แค่ช่าง)
- ระบบแจ้งซ่อมผ่านไลน์ (linelift) เพื่อให้มีรูปแบบการแจ้งซ่อมที่หลากหลาย ไม่ใช่แค่แจ้้งผ่านแอป
- สรุปเป็นกราฟ PM จากการบันทึกรายปี
- กราฟรายงานใบแจ้ง (มีหรือไม่มี แล้วแต่ละรายการมีเท่าไหร่ช่างคนไหนทำบ้าง)
