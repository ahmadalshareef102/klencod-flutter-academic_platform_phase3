part of '../../main.dart';

// ───────────────────────── تسجيل الدخول ─────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    var hasSession = false;
    try {
      hasSession = isSupabaseConfigured && db.auth.currentUser != null;
    } catch (_) {
      hasSession = false;
    }
    if (hasSession) {
      _restoring = true;
      _restore();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final u = await loadAppUser(db.auth.currentUser!);
      if (!mounted) return;
      _enter(u);
    } catch (_) {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _enter(AppUser u) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(user: u)));
  }

  Future<void> _login() async {
    if (!isSupabaseConfigured) {
      _message('لم يتم إعداد Supabase بعد.');
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _message('أدخل البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await db.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthException('تعذر التحقق من الحساب');
      final u = await loadAppUser(user);
      if (!mounted) return;
      _enter(u);
    } on AuthException catch (e) {
      _message(e.message);
    } on PostgrestException catch (e) {
      _message('تعذر تحميل ملف الحساب: ${e.message}');
    } catch (e) {
      _message('تعذر تسجيل الدخول: ${errText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) => snack(context, text);

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x22102A43), blurRadius: 24, offset: Offset(0, 10))]),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 22),
              const Text('المنصة الأكاديمية الرقمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 8),
              const Text('إدارة ومتابعة العملية التعليمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              const Text('جامعة الحديدة · كلية التربية – زبيد', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF8291A5))),
              const SizedBox(height: 34),
              const Text('تسجيل الدخول', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: navy)),
              const SizedBox(height: 6),
              const Text('استخدم بيانات الحساب الذي أنشأته إدارة الكلية', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 22),
              const FieldLabel('البريد الإلكتروني'),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: const InputDecoration(hintText: 'name@example.com', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 16),
              const FieldLabel('كلمة المرور'),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                onSubmitted: (_) => _login(),
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(hintText: 'أدخل كلمة المرور', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _login,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                label: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(_busy ? 'جارٍ التحقق...' : 'دخول إلى المنصة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                style: FilledButton.styleFrom(backgroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(14)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.security_rounded, color: blue),
                  SizedBox(width: 10),
                  Expanded(child: Text('تسجيل الدخول مرتبط بخدمة Supabase. صلاحية المستخدم تُقرأ من قاعدة البيانات ولا يختارها المستخدم بنفسه.', style: TextStyle(fontSize: 12, height: 1.6, color: navy))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
