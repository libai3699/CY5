import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';
import 'contact_page.dart';
import 'data/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.config, this.onLoginSuccess});

  final Map<String, String>? config;
  final void Function(AuthSession)? onLoginSuccess;

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
  String? _usernameError;
  String? _passwordError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(bool register) async {
    final username = _username.text.trim();
    final password = _password.text;
    print(
        '[AUTH_PAGE] submit start mode=${register ? "register" : "login"} username=$username');

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = null;
        _usernameError = username.isEmpty ? '请填写账号' : null;
        _passwordError = password.isEmpty ? '请填写密码' : null;
      });
      return;
    }

    if (register) {
      final validUsername = username.length >= 6 &&
          RegExp(r'[A-Za-z]').hasMatch(username) &&
          RegExp(r'\d').hasMatch(username);
      if (!validUsername) {
        setState(() {
          _message = null;
          _usernameError = '账号至少6位，且必须同时包含字母和数字';
          _passwordError = null;
        });
        return;
      }
      if (password.length < 6) {
        setState(() {
          _message = null;
          _usernameError = null;
          _passwordError = '密码至少6位';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _message = null;
      _usernameError = null;
      _passwordError = null;
    });

    try {
      final session = register
          ? await _auth.register(username: username, password: password)
          : await _auth.login(username: username, password: password);
      print(
          '[AUTH_PAGE] submit success mode=${register ? "register" : "login"} username=$username');
      if (!mounted) return;

      // 如果有回调，调用回调；否则返回session
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(session);
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop(session);
      }
    } catch (error) {
      print(
          '[AUTH_PAGE] submit error mode=${register ? "register" : "login"} username=$username error=$error');
      final text = error.toString();
      setState(() {
        if (text.contains('用户名') ||
            text.contains('账号') ||
            text.contains('1001') ||
            text.contains('1002')) {
          _usernameError = text;
          _passwordError = null;
          _message = null;
        } else if (text.contains('密码')) {
          _usernameError = null;
          _passwordError = text;
          _message = null;
        } else {
          _usernameError = null;
          _passwordError = null;
          _message = text;
        }
      });
      // 超出注册限制时跳转客服页面
      if (text.contains('1004') ||
          text.contains('客服') ||
          text.contains('3 个')) {
        if (mounted) _openContact();
      }
    } finally {
      print(
          '[AUTH_PAGE] submit finish mode=${register ? "register" : "login"} username=$username mounted=$mounted');
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = PlatformUtils.getContentMaxWidth();
    final pagePadding = PlatformUtils.getPagePadding();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: contentMaxWidth ?? double.infinity,
            ),
            child: SingleChildScrollView(
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 返回按钮
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Color(0xFF881337)),
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
                    decoration: InputDecoration(
                      labelText: '账号',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: const OutlineInputBorder(),
                      errorText: _usernameError,
                    ),
                    onChanged: (_) {
                      if (_usernameError != null)
                        setState(() => _usernameError = null);
                    },
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
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        color: const Color(0xFF9F1239),
                      ),
                    ),
                    onChanged: (_) {
                      if (_passwordError != null)
                        setState(() => _passwordError = null);
                    },
                  ),
                  // 错误提示
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFE11D48), fontSize: 13),
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
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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
                    child: const Text('注册',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 16),
                  // 忘记密码提示
                  GestureDetector(
                    onTap: _openContact,
                    child: const Text(
                      '忘记密码？联系客服找回',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9F1239),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 注册限制提示
                  const Text(
                    '每台设备最多注册 3 个账号',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
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
