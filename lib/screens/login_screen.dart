import 'package:flutter/material.dart';
import 'home_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: '1234');

  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;

  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(
        0.0,
        0.65,
        curve: Curves.easeIn,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.78,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _textFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(
        0.45,
        1.0,
        curve: Curves.easeIn,
      ),
    );

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // هذا الانتقال مؤقت كما كان في الكود الأصلي.
    // يجب استبداله لاحقاً بتحقق حقيقي من بيانات المستخدم.
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),

                  // الشعار: ظهور تدريجي + تكبير سلس من 78% إلى الحجم الطبيعي.
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: Container(
                        width: 155,
                        height: 155,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF071426),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF071426).withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/store_logo.png',
                            width: 143,
                            height: 143,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  FadeTransition(
                    opacity: _textFade,
                    child: const Column(
                      children: [
                        Text(
                          'E-Store',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F5132),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'سجّل الدخول للمتابعة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 34),

                  const Text(
                    'اسم المستخدم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F5132),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _userCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'أدخل اسم المستخدم',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'اسم المستخدم مطلوب';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'كلمة المرور',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F5132),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_loading) _login();
                    },
                    decoration: InputDecoration(
                      hintText: 'أدخل كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscure = !_obscure);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور مطلوبة';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() => _rememberMe = value ?? false);
                        },
                        activeColor: const Color(0xFF0F5132),
                      ),
                      const Text(
                        'تذكرني',
                        style: TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'يرجى التواصل مع مسؤول النظام لاستعادة كلمة المرور',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            color: Color(0xFF0F5132),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5132),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ليس لديك حساب؟ ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى التواصل معنا لإنشاء حساب'),
                            ),
                          );
                        },
                        child: const Text(
                          'تواصل معنا',
                          style: TextStyle(
                            color: Color(0xFF0F5132),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
