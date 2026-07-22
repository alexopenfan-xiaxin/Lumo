import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/auth_client.dart';
import 'package:lumo/chat_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('repairs malformed persisted request identity', () async {
    const channel = MethodChannel('app.lumo.companion/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'invalid-device-id');
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final store = ChatStore(
      factory: databaseFactoryFfi,
      databasePath: ':memory:',
    );
    await store.saveSetting('guest_id', 'broken');
    await store.saveSetting('auth_session', '[]');
    final client = AuthClient(store: store);

    final identity = await client.identity();

    expect(identity.guestId, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(await store.setting('guest_id'), identity.guestId);
    expect(await client.session(), isNull);
    expect(await store.setting('auth_session'), isNull);
  });

  // ponytail: one check that the new membership/order payloads parse with correct defaults.
  test('parses membership status and create-order result JSON', () {
    final monthly = MembershipStatus.fromJson(const {
      'isMember': true,
      'plan': 'monthly',
      'expireAt': 1_700_000_000_000,
      'contextLimit': 256000,
      'dailyMessages': 200,
    });
    expect(monthly.isMember, isTrue);
    expect(monthly.plan, 'monthly');
    expect(monthly.expireAt, 1_700_000_000_000);
    expect(monthly.contextLimit, 256000);
    expect(monthly.dailyMessages, 200);

    // Defaults: missing contextLimit falls back to 128k; missing plan/expireAt/messages go null.
    final fallback = MembershipStatus.fromJson(const {'isMember': false});
    expect(fallback.contextLimit, 128000);
    expect(fallback.plan, isNull);
    expect(fallback.expireAt, isNull);
    expect(fallback.dailyMessages, isNull);

    final order = CreateOrderResult.fromJson(const {
      'qrcode': 'https://example.com/pay',
      'trade_no': 'LUMO_1_abc',
    });
    expect(order.qrcode, 'https://example.com/pay');
    expect(order.tradeNo, 'LUMO_1_abc');
  });
}
