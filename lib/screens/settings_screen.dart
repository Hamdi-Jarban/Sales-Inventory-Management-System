import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:untitled2/controller/settings_controller.dart';

const _primary = Color(0xFF0F5132);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsController _settings = SettingsController();

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _senderCtrl = TextEditingController(text: 'المتجر');
  bool _useSsl = false;
  bool _obscurePass = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settings.getSmtpSettings();
    if (!mounted) return;
    setState(() {
      _hostCtrl.text = s.host ?? '';
      _portCtrl.text = s.port.toString();
      _userCtrl.text = s.username ?? '';
      _passCtrl.text = s.password ?? '';
      _senderCtrl.text = s.senderName;
      _useSsl = s.useSsl;
      _loading = false;
    });
  }

  SmtpSettings _collect() => SmtpSettings(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 587,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        senderName: _senderCtrl.text.trim().isEmpty ? 'المتجر' : _senderCtrl.text.trim(),
        useSsl: _useSsl,
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _settings.saveSmtpSettings(_collect());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات البريد')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final s = _collect();
    if (!s.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تعبئة الخادم واسم المستخدم وكلمة المرور أولاً'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _testing = true);
    try {
      final server = SmtpServer(s.host!, port: s.port, username: s.username, password: s.password, ssl: s.useSsl);
      final message = Message()
        ..from = Address(s.username!, s.senderName)
        ..recipients.add(s.username!)
        ..subject = 'رسالة اختبار من نظام المتجر'
        ..text = 'هذه رسالة اختبار للتأكد من صحة إعدادات البريد.';
      await send(message, server);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الاتصال والإرسال بنجاح ✓'), backgroundColor: Colors.green));
    } on MailerException catch (e) {
      final msg = e.problems.isNotEmpty ? e.problems.first.msg : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الاختبار: $msg'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل الاتصال بخادم البريد — تحقق من البيانات والإنترنت'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('إعدادات البريد الإلكتروني')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تُستخدم هذه البيانات لإرسال تذكيرات الديون للعملاء عبر البريد الإلكتروني، وتُخزَّن على جهازك فقط.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field('خادم SMTP (Host)', _hostCtrl, hint: 'smtp.gmail.com'),
                  _field('المنفذ (Port)', _portCtrl, keyboard: TextInputType.number, hint: '587'),
                  _field('اسم المستخدم / البريد', _userCtrl, keyboard: TextInputType.emailAddress),
                  _field('كلمة المرور', _passCtrl, obscure: _obscurePass, suffix: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  )),
                  _field('اسم المُرسِل الظاهر', _senderCtrl),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('استخدام SSL'),
                    value: _useSsl,
                    activeColor: _primary,
                    onChanged: (v) => setState(() => _useSsl = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('اختبار الاتصال'),
                          style: OutlinedButton.styleFrom(foregroundColor: _primary, minimumSize: const Size(0, 46)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                          label: const Text('حفظ', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: _primary, minimumSize: const Size(0, 46)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, bool obscure = false, String? hint, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
