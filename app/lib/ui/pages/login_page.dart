import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int _loginMode = 1; // 0=验证码, 1=密码
  final _smsFormKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  int _countdown = 60;
  Timer? _countdownTimer;
  final _pwdFormKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final auth = context.read<AuthProvider>();
    await auth.checkLoginStatus();
    if (mounted && auth.isLoggedIn) {
      _onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90D9), Color(0xFF357ABD), Color(0xFF2A6CB0)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (canPop)
                Positioned(
                  top: 8, right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                ),
              Center(
              child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.auto_stories, size: 48, color: Color(0xFF4A90D9)),
                ),
                const SizedBox(height: 20),
                const Text('AI背单词', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text('智能学习，高效记忆', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 36),
                // 卡片
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(children: [
                    // 切换按钮
                    _buildModeToggle(),
                    const SizedBox(height: 28),
                    // 表单
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _loginMode == 0 ? _buildSmsForm() : _buildPasswordForm(),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('登录即表示同意用户协议和隐私政策', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 40),
              ]),
            ),
          ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        _buildToggleTab('验证码登录', 0),
        _buildToggleTab('密码登录', 1),
      ]),
    );
  }

  Widget _buildToggleTab(String label, int mode) {
    final selected = _loginMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _loginMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4A90D9) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? [BoxShadow(color: const Color(0xFF4A90D9).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey.shade500)),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFF4A90D9), size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4A90D9), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }

  Widget _buildSmsForm() {
    return Form(
      key: _smsFormKey,
      child: Column(key: const ValueKey('sms'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _mobileController,
          decoration: _inputDecoration(hint: '请输入手机号', icon: Icons.phone_android),
          keyboardType: TextInputType.phone, maxLength: 11,
          buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return '请输入手机号';
            if (v.length != 11) return '请输入11位手机号';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _codeController,
          decoration: _inputDecoration(hint: '请输入验证码', icon: Icons.shield_outlined,
            suffix: _buildCodeButton()),
          keyboardType: TextInputType.number, maxLength: 6,
          buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return '请输入验证码';
            if (v.length != 6) return '请输入6位验证码';
            return null;
          },
        ),
        const SizedBox(height: 28),
        _buildLoginButton(_loginWithCode),
      ]),
    );
  }

  Widget _buildCodeButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: _codeSent ? null : _sendCode,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _codeSent ? '${_countdown}s' : '获取验证码',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: _codeSent ? Colors.grey.shade400 : const Color(0xFF4A90D9)),
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _pwdFormKey,
      child: Column(key: const ValueKey('pwd'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _accountController,
          decoration: _inputDecoration(hint: '用户名 / 手机号', icon: Icons.person_outline),
          validator: (v) => (v == null || v.isEmpty) ? '请输入用户名或手机号' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration(hint: '请输入密码', icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey.shade400, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )),
          validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
        ),
        const SizedBox(height: 28),
        _buildLoginButton(_loginWithPassword),
      ]),
    );
  }

  Widget _buildLoginButton(VoidCallback onPressed) {
    return Consumer<AuthProvider>(builder: (context, auth, _) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF5B9BD5), Color(0xFF3A7BD5)]),
          boxShadow: [BoxShadow(color: const Color(0xFF4A90D9).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: auth.isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: auth.isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : const Text('登 录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
      );
    });
  }

  Future<void> _sendCode() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length != 11) { _showSnack('请输入正确的手机号', Colors.orange); return; }
    final auth = context.read<AuthProvider>();
    await auth.sendCode(mobile);
    if (!mounted) return;
    if (auth.error == null) { _showSnack('验证码已发送', Colors.green); _startCountdown(); }
    else { _showSnack(auth.error!, Colors.red); }
  }

  Future<void> _loginWithCode() async {
    if (!_smsFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_mobileController.text.trim(), _codeController.text.trim());
    if (!mounted) return;
    _handleResult(auth);
  }

  Future<void> _loginWithPassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.loginByPassword(_accountController.text.trim(), _passwordController.text);
    if (!mounted) return;
    _handleResult(auth);
  }

  void _handleResult(AuthProvider auth) {
    if (auth.isLoggedIn) { _onLoginSuccess(); }
    else if (auth.error != null) { _showSnack(auth.error!, Colors.red); }
  }

  void _onLoginSuccess() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _startCountdown() {
    setState(() { _codeSent = true; _countdown = 60; });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) { setState(() => _countdown--); }
      else { t.cancel(); setState(() => _codeSent = false); }
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mobileController.dispose();
    _codeController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
