import 'package:sqflite/sqflite.dart';
import 'package:untitled2/database.dart';

/// ═══════════════════════════════════════════════════════════════
/// SettingsController
/// إعدادات التطبيق (key/value) داخل SQLite — تُستخدم لتخزين إعداد
/// خادم البريد (SMTP) الذي يُدخله المستخدم من شاشة الإعدادات، حتى
/// لا تُكتب أي بيانات اعتماد (password / API key) داخل الكود
/// المصدري مباشرة.
/// ═══════════════════════════════════════════════════════════════
class SettingsController {
  final table = 'settings';

  // مفاتيح إعداد SMTP
  static const kSmtpHost = 'smtp_host';
  static const kSmtpPort = 'smtp_port';
  static const kSmtpUsername = 'smtp_username';
  static const kSmtpPassword = 'smtp_password';
  static const kSmtpSenderName = 'smtp_sender_name';
  static const kSmtpUseSsl = 'smtp_use_ssl';

  Future<String?> get(String key) async {
    final rows = await DatabaseService.instance
        .rawQuery('SELECT value FROM settings WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<Map<String, String?>> getAll(List<String> keys) async {
    final result = <String, String?>{};
    for (final k in keys) {
      result[k] = await get(k);
    }
    return result;
  }

  Future<void> set(String key, String? value) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setMany(Map<String, String?> values) async {
    for (final entry in values.entries) {
      await set(entry.key, entry.value);
    }
  }

  /// إعدادات SMTP الحالية مجمَّعة في كائن واحد جاهز للاستخدام.
  Future<SmtpSettings> getSmtpSettings() async {
    final map = await getAll([
      kSmtpHost,
      kSmtpPort,
      kSmtpUsername,
      kSmtpPassword,
      kSmtpSenderName,
      kSmtpUseSsl,
    ]);
    return SmtpSettings(
      host: map[kSmtpHost],
      port: int.tryParse(map[kSmtpPort] ?? '') ?? 587,
      username: map[kSmtpUsername],
      password: map[kSmtpPassword],
      senderName: map[kSmtpSenderName] ?? 'المتجر',
      useSsl: map[kSmtpUseSsl] == '1',
    );
  }

  Future<void> saveSmtpSettings(SmtpSettings s) async {
    await setMany({
      kSmtpHost: s.host,
      kSmtpPort: s.port.toString(),
      kSmtpUsername: s.username,
      kSmtpPassword: s.password,
      kSmtpSenderName: s.senderName,
      kSmtpUseSsl: s.useSsl ? '1' : '0',
    });
  }
}

class SmtpSettings {
  final String? host;
  final int port;
  final String? username;
  final String? password;
  final String senderName;
  final bool useSsl;

  SmtpSettings({
    this.host,
    this.port = 587,
    this.username,
    this.password,
    this.senderName = 'المتجر',
    this.useSsl = false,
  });

  bool get isConfigured =>
      (host != null && host!.trim().isNotEmpty) &&
      (username != null && username!.trim().isNotEmpty) &&
      (password != null && password!.trim().isNotEmpty);
}
