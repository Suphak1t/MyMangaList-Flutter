/// รวมที่อยู่ API ไว้จุดเดียว เพื่อให้ทุกหน้าต่อ URL ของ endpoint เหมือนกัน
class ApiConfig {
  // ใช้สำหรับรันผ่าน Windows Desktop
  // ถ้ารันบน Android Emulator ให้ใช้ http://10.0.2.2/mymangalist_api
  // ถ้ารันบนโทรศัพท์จริง ให้ใช้ IP เครื่อง เช่น http://192.168.1.100/mymangalist_api
  static const String baseUrl = 'http://localhost/mymangalist_api';
}
