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
├── main.dart                  # Entry point ของแอป
├── constants.dart             # ค่าคงที่ที่ใช้ร่วมกัน
├── components/                # (ลบแล้ว)
├── screens/                   # หน้าจอหลัก เช่น about, bug report, role selection, work order overview
│   ├── about_screen.dart
│   ├── bug_report_screen.dart
│   ├── role_selection_screen.dart
│   ├── work_order_overview_screen.dart
├── tabs/                      # Tab หลักของแอป (แต่ละฟีเจอร์)
│   ├── repair_tab.dart
│   ├── customer_feedback_tab.dart
│   ├── work_order_tab.dart
│   ├── pm_tab.dart
│   ├── repair_summary_tab.dart
│   ├── pm_summary_tab.dart
│   └── work_report_tab.dart
├── pm_page/                   # หน้า PM แยกตามโซน
│   ├── pm_zone_widget.dart
│   ├── zone1.dart
│   ├── zone2.dart
│   ├── zone3.dart
│   ├── zone4.dart
│   └── zone5.dart
assets/
└── icon/                      # โลโก้และไอคอน
    └── logo_SMH.png
```
## 🛠️ วิธีติดตั้งและรันโปรเจกต์ (Step by Step)

### 1. ติดตั้ง Flutter SDK
- ดาวน์โหลดและติดตั้ง Flutter ตามคู่มือ [Flutter Install](https://docs.flutter.dev/get-started/install)
- ตรวจสอบว่าเครื่องมี git และ dart ด้วย (Flutter จะติดตั้ง Dart ให้อัตโนมัติ)

### 2. Clone โปรเจกต์จาก GitHub
```sh
# เปลี่ยน URL ให้ตรงกับ repo ของคุณ
 git clone https://github.com/yourusername/repair-app.git
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
- เลือก device ที่ต้องการ (Android/iOS/Windows/Mac/Linux/Web)
- ถ้าเจอ error device ไม่เจอ ให้รัน `flutter devices` หรือเปิด emulator ก่อน

### 5. (Optional) ดู dependencies ทั้งหมด
- เปิดไฟล์ `pubspec.yaml` (หลัก)
- หรือดูไฟล์ `pub_dependencies.txt` (dependency tree)

### 6. Troubleshooting เบื้องต้น
- ถ้าเจอ error ให้รัน `flutter doctor` เพื่อตรวจสอบสภาพแวดล้อม
- ถ้า build ไม่ผ่าน ลองรัน `flutter clean` แล้ว `flutter pub get` ใหม่
- ถ้า clone มาแล้วรันไม่ได้ ให้เช็คว่าใช้ Flutter เวอร์ชันตรงกับใน `pubspec.yaml` (เช่น sdk: ^3.7.2)

---
## 📱 เทคโนโลยีที่ใช้

- **Flutter**: UI Framework
- **Dart**: Programming Language
- **HTTP**: API Communication
- **SharedPreferences**: Local Storage
- **Google Apps Script**: Backend API

## 📄 License

MIT License
