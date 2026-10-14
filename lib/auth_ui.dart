import 'package:flutter/material.dart';

/// โครงหน้าตาร่วมของหน้า Login และ Register; children คือช่องและปุ่มของแต่ละหน้า
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.headingTextAlign = TextAlign.start,
  });

  // ข้อมูลที่หน้าลูกส่งมาเพื่อเติมหัวข้อ คำอธิบาย และช่องฟอร์ม
  final String title;
  final String subtitle;
  final List<Widget> children;
  final TextAlign headingTextAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // พื้นหลังไล่สีและ SafeArea ป้องกันเนื้อหาชนขอบหน้าจอ
    return DecoratedBox(
      decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.55),
            colors.surface,
          ],
        ),
      ),
      child: SafeArea(
        // อ่านความสูงพื้นที่จริงแล้วให้ฟอร์มเลื่อนได้เมื่อจอเล็ก
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // กำหนดให้ Row หรือ Column ใช้พื้นที่ตามเนื้อหาหรือเต็มแกน
                    crossAxisAlignment: CrossAxisAlignment.stretch, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                    children: [
                      Center(
                        child: Container(
                          width: 72, // ความกว้างของพื้นที่แสดงหรือรูปภาพ
                          height: 72, // ความสูงของพื้นที่แสดงหรือรูปภาพ
                          decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(22), // ความโค้งของมุมกรอบ
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 36,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // เว้นระยะห่างแนวตั้ง 16 พิกเซล
                      Text(
                        'MyMangaList',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 32), // เว้นระยะห่างแนวตั้ง 32 พิกเซล
                      Container(
                        padding: const EdgeInsets.all(28), // ระยะว่างด้านในระหว่างขอบกับเนื้อหา
                        decoration: BoxDecoration( // กำหนดสี ขอบ หรือเงาของกล่องนี้
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24), // ความโค้งของมุมกรอบ
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch, // จัดแนวลูกตามแกนขวางของ Row หรือ Column
                          mainAxisSize: MainAxisSize.min, // กำหนดให้ Row หรือ Column ใช้พื้นที่ตามเนื้อหาหรือเต็มแกน
                          children: [
                            Text(
                              title,
                              textAlign: headingTextAlign,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6), // เว้นระยะห่างแนวตั้ง 6 พิกเซล
                            Text(
                              subtitle,
                              textAlign: headingTextAlign,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 28), // เว้นระยะห่างแนวตั้ง 28 พิกเซล
                            ...children,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// รูปแบบช่องกรอกที่ใช้ซ้ำ รวม icon และสีขอบเมื่อเลือกช่อง
InputDecoration authInputDecoration(
  BuildContext context, { // ตำแหน่ง widget ที่ใช้หา Theme สีของหน้าปัจจุบัน
  required String label, // ข้อความชื่อช่องที่จะส่งต่อให้ labelText
  required IconData icon, // รูปไอคอนที่จะวางไว้ด้านหน้าช่อง
}) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14), // ความโค้งของมุมกรอบ
    borderSide: BorderSide.none,
  );

  return InputDecoration(
    labelText: label, // ข้อความชื่อช่องที่แสดงในฟอร์ม
    prefixIcon: Icon(icon), // ไอคอนด้านหน้าของช่องกรอก
    filled: true, // เปิดการระบายสีพื้นหลังช่องกรอก
    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55), // สีพื้นช่องแบบโปร่งบางส่วน
    border: border, // รูปแบบขอบพื้นฐานของช่อง
    enabledBorder: border, // ขอบเมื่อช่องใช้งานได้แต่ยังไม่ถูกเลือก
    focusedBorder: border.copyWith( // ขอบเมื่อผู้ใช้แตะและกำลังพิมพ์ในช่อง
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), // ระยะว่างภายในส่วนเนื้อหาของ widget
  );
}

/// รูปแบบปุ่มหลักร่วมของฟอร์มยืนยันตัวตน
ButtonStyle authPrimaryButtonStyle(BuildContext context) {
  return ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(54), // ปุ่มสูงอย่างน้อย 54 พิกเซล
    backgroundColor: Theme.of(context).colorScheme.primary, // สีพื้นปุ่มตาม Theme
    foregroundColor: Theme.of(context).colorScheme.onPrimary, // สีข้อความที่อ่านชัดบนพื้นปุ่ม
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}
