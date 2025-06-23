# Repair Management App

แอปพลิเคชันจัดการงานซ่อมบำรุงและ PM (Preventive Maintenance) สำหรับโรงงานอุตสาหกรรม

## 🚀 คุณสมบัติหลัก

- **แจ้งซ่อม**: ระบบแจ้งซ่อมเครื่องจักร
- **ประเมิน**: ระบบประเมินผลการซ่อมจากลูกค้า
- **งานช่าง**: ระบบบันทึกรายงานงานช่าง
- **PM**: ระบบจัดการ Preventive Maintenance
- **สรุปการซ่อม**: รายงานสรุปการซ่อม
- **สรุป PM**: รายงานสรุป PM

## 📁 โครงสร้างโปรเจค

```
lib/
├── main.dart                 # Entry point ของแอป
├── constants.dart            # ค่าคงที่ที่ใช้ร่วมกัน
├── Auth_Service.dart         # บริการ Authentication
├── components/               # Components ที่ใช้ร่วมกัน
│   └── profile_button.dart
├── screens/                  # หน้าจอต่างๆ
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── profile_settings_screen.dart
│   └── repair_history_screen.dart
├── tabs/                     # Tab หลักของแอป
│   ├── repair_tab.dart
│   ├── customer_feedback_tab.dart
│   ├── work_order_tab.dart
│   ├── pm_tab.dart
│   ├── repair_summary_tab.dart
│   ├── pm_summary_tab.dart
│   └── work_report_tab.dart
└── pm_page/                  # หน้า PM แยกตามโซน
    └── zone1.dart
```

## 🎨 การปรับปรุงโค้ด

### 1. การจัดระเบียบโค้ด
- สร้างไฟล์ `constants.dart` เพื่อเก็บค่าคงที่ที่ใช้ร่วมกัน
- แยก API URLs, colors, text styles, และ dimensions
- ใช้ consistent naming conventions

### 2. การลบโค้ดที่ไม่ได้ใช้
- ลบไฟล์ `zone2.dart` ที่มีเนื้อหาซ้ำกัน
- ลบไฟล์ `history_tab.dart` ที่ไม่ได้ใช้
- ปรับปรุง import statements

### 3. การปรับปรุง UI/UX
- ใช้ consistent styling ด้วย AppConstants
- ปรับปรุง navigation bar ให้สวยงาม
- เพิ่ม visual feedback สำหรับสถานะต่างๆ

### 4. การปรับปรุง Performance
- ใช้ `const` constructors ที่เหมาะสม
- ลดการสร้าง objects ที่ไม่จำเป็น
- ปรับปรุง error handling

## 🛠️ การติดตั้งและรัน

1. ติดตั้ง Flutter SDK
2. Clone โปรเจค
3. รัน `flutter pub get`
4. รัน `flutter run`

## 📱 เทคโนโลยีที่ใช้

- **Flutter**: UI Framework
- **Dart**: Programming Language
- **HTTP**: API Communication
- **SharedPreferences**: Local Storage
- **Google Apps Script**: Backend API

## 🔧 การพัฒนา

### การเพิ่มโซนใหม่
1. สร้างไฟล์ `zoneX.dart` ใน `pm_page/`
2. อัปเดต `pm_tab.dart` เพื่อเพิ่มโซนใหม่
3. เพิ่ม API endpoint สำหรับโซนใหม่

### การเพิ่มฟีเจอร์ใหม่
1. สร้างไฟล์ใหม่ในโฟลเดอร์ที่เหมาะสม
2. อัปเดต `constants.dart` หากจำเป็น
3. เพิ่ม navigation ใน `main.dart` หากจำเป็น

## 📄 License

MIT License
