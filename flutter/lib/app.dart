import 'package:flutter/material.dart';

import 'pages/vpn_home/vpn_home_page.dart';

class YuexiaVpnApp extends StatelessWidget {
  const YuexiaVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '9点9 VPN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE11D48),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const VpnHomePage(),
    );
  }
}
