import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cy_vpn/app.dart';

void main() {
  testWidgets('CY VPN home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const YuexiaVpnApp());

    expect(find.text('9点9 VPN'), findsWidgets);
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });
}
