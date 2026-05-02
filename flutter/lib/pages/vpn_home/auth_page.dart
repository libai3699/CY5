import 'package:flutter/material.dart';

import 'contact_page.dart';
import 'data/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.config});

  final Map<String, String> config;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _auth = const AuthService();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(bool register) async {
    final username = _username.text.trim();
    final password = _password.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _message = '请填写账号和密码');
      return;
    }

    if (register) {
      final validUsername = username.length >= 6 &&
          RegExp(r'[A-Za-z]').hasMatch(username) &&
          RegExp(r'\d').hasMatch(username);
      if (!validUsername) {
        setState(() => _message = '账号至少6位，且必须同时包含字母和数字');
        return;
      }
      if (password.length < 6) {
        setState(() => _message = '密码至少6位');
        return;
      }
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final session = register
          ? await _auth.register(username: username, password: password)
          : await _auth.login(username: username, password: password);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (error) {
      final text = error.toString();
      setState(() => _message = text);
      // 超出注册限制时跳转客服页面
      if (text.contains('1004') || text.contains('客服') || text.contains('3 个')) {
        if (mounted) _openContact();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openContact() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ContactPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 返回按钮
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF881337)),
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              const Text(
                '账号登录',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              // 账号输入框
              TextField(
                controller: _username,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '账号',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 密码输入框（带小眼睛）
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _loading ? null : _submit(false),
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    color: const Color(0xFF9F1239),
                  ),
                ),
              ),
              // 错误提示
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),
              // 登录按钮（主操作，放上面）
              FilledButton(
                onPressed: _loading ? null : () => _submit(false),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFE11D48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _loading ? '处理中...' : '登录',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              // 注册按钮（次操作，放下面）
              OutlinedButton(
                onPressed: _loading ? null : () => _submit(true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                  foregroundColor: const Color(0xFFE11D48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('注册', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
