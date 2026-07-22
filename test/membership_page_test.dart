import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/auth_client.dart';
import 'package:lumo/pages/membership_page.dart';

void main() {
  testWidgets('payment countdown keeps moving while a poll is pending', (
    tester,
  ) async {
    final client = _PaymentAuthClient();
    await tester.pumpWidget(
      MaterialApp(home: MembershipPage(authClient: client)),
    );
    await tester.pump();
    await tester.tap(find.text('立即开通'));
    await tester.pumpAndSettle();

    expect(find.text('正在等待支付结果…（60s）'), findsOneWidget);
    await tester.tap(find.text('我已支付完成'));
    await tester.pumpAndSettle();
    expect(find.text('暂未检测到支付记录，请确认已扫码完成支付。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(client.membershipChecks, 3);
    expect(find.text('正在等待支付结果…（57s）'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('正在等待支付结果…（56s）'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PaymentAuthClient extends AuthClient {
  int membershipChecks = 0;

  @override
  Future<MembershipStatus> checkMembership() {
    membershipChecks++;
    if (membershipChecks <= 2) {
      return Future.value(
        const MembershipStatus(
          isMember: false,
          plan: null,
          expireAt: null,
          contextLimit: 128000,
          dailyMessages: null,
        ),
      );
    }
    return Completer<MembershipStatus>().future;
  }

  @override
  Future<CreateOrderResult> createOrder() => Future.value(
    const CreateOrderResult(qrcode: 'https://example.com/pay', tradeNo: '1'),
  );
}
