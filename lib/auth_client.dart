import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'chat_store.dart';

class AuthClient {
  AuthClient({ChatStore? store, String? endpoint})
    : _store = store ?? ChatStore(),
      _endpoint = endpoint ?? const String.fromEnvironment('LUMO_AI_ENDPOINT');

  static const _sessionKey = 'auth_session';
  static const _guestKey = 'guest_id';
  static final _guestIdPattern = RegExp(r'^[a-f0-9]{32}$');

  final ChatStore _store;
  final String _endpoint;

  Future<AccountSession?> session() async {
    final saved = await _store.setting(_sessionKey);
    if (saved == null) return null;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid account session');
      }
      return AccountSession.fromJson(decoded);
    } on FormatException {
      await _store.saveSetting(_sessionKey, null);
      return null;
    }
  }

  Future<RequestIdentity> identity() async {
    final storedGuestId = await _store.setting(_guestKey);
    var guestId = storedGuestId;
    try {
      guestId =
          await const MethodChannel(
            'app.lumo.companion/device',
          ).invokeMethod<String>('getId') ??
          guestId;
    } on MissingPluginException {
      // Tests and non-Android hosts use the persisted random identifier below.
    } on PlatformException {
      // A platform identity failure must not prevent the guest experience.
    }
    if (guestId == null || !_guestIdPattern.hasMatch(guestId)) {
      final random = Random.secure();
      guestId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    final validGuestId = guestId;
    if (validGuestId != storedGuestId) {
      await _store.saveSetting(_guestKey, validGuestId);
    }
    return RequestIdentity(
      guestId: validGuestId,
      token: (await session())?.token,
    );
  }

  Future<AccountSession> login(String username, String password) =>
      _authenticate('/auth/login', {
        'username': username,
        'password': password,
      });

  Future<AccountSession> register(
    String username,
    String password,
    String inviteCode,
  ) => _authenticate('/auth/register', {
    'username': username,
    'password': password,
    'inviteCode': inviteCode,
  });

  Future<void> logout() => _store.saveSetting(_sessionKey, null);

  Future<MembershipStatus> checkMembership() async {
    final current = await session();
    if (current == null) throw const AuthException('请先登录。');
    return MembershipStatus.fromJson(
      await _request('GET', '/membership', null, token: current.token),
    );
  }

  Future<CreateOrderResult> createOrder() async {
    final current = await session();
    if (current == null) throw const AuthException('请先登录。');
    return CreateOrderResult.fromJson(
      await _request('POST', '/create-order', null, token: current.token),
    );
  }

  Future<AccountSession> updateAccount({
    required String currentPassword,
    String? username,
    String? newPassword,
  }) async {
    final current = await session();
    if (current == null) throw const AuthException('请先登录。');
    final body = <String, String>{'currentPassword': currentPassword};
    if (username != null) body['username'] = username;
    if (newPassword != null) body['newPassword'] = newPassword;
    final response = await _request(
      'PATCH',
      '/auth/account',
      body,
      token: current.token,
    );
    late final AccountSession account;
    try {
      account = AccountSession.fromJson(response);
    } on FormatException {
      throw const AuthException('账号服务暂时不可用。');
    }
    await _store.saveSetting(_sessionKey, jsonEncode(account.toJson()));
    return account;
  }

  Future<AccountSession> _authenticate(
    String path,
    Map<String, String> body,
  ) async {
    final response = await _request('POST', path, body);
    late final AccountSession account;
    try {
      account = AccountSession.fromJson(response);
    } on FormatException {
      throw const AuthException('账号服务暂时不可用。');
    }
    await _store.saveSetting(_sessionKey, jsonEncode(account.toJson()));
    return account;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, String>? body, {
    String? token,
  }) async {
    if (_endpoint.isEmpty) throw const AuthException('账号服务还没有部署完成。');
    final endpoint = Uri.parse(_endpoint);
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        endpoint.replace(path: path, query: null),
      );
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final decoded = jsonDecode(await utf8.decoder.bind(response).join());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid account response');
      }
      if (response.statusCode != HttpStatus.ok) {
        final error = decoded['error'];
        throw AuthException(error is String ? error : '账号操作失败，请稍后再试。');
      }
      return decoded;
    } on SocketException {
      throw const AuthException('网络好像开小差了，请稍后再试。');
    } on FormatException {
      throw const AuthException('账号服务暂时不可用。');
    } finally {
      client.close(force: true);
    }
  }
}

class AccountSession {
  const AccountSession({
    required this.username,
    required this.token,
    required this.isMember,
    required this.role,
  });

  final String username;
  final String token;
  final bool isMember;
  final String role;

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    final token = json['token'];
    final role = json['role'];
    if (username is! String || token is! String || role is! String) {
      throw const FormatException('Invalid account session');
    }
    return AccountSession(
      username: username,
      token: token,
      isMember: json['isMember'] == true,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'token': token,
    'isMember': isMember,
    'role': role,
  };
}

class RequestIdentity {
  const RequestIdentity({required this.guestId, required this.token});

  final String guestId;
  final String? token;
}

class MembershipStatus {
  const MembershipStatus({
    required this.isMember,
    required this.plan,
    required this.expireAt,
    required this.contextLimit,
    required this.dailyMessages,
  });

  final bool isMember;
  final String? plan; // 'monthly' | 'permanent' | null
  final int? expireAt; // ms since epoch; null for permanent or non-member
  final int contextLimit;
  final int? dailyMessages; // null = unlimited

  factory MembershipStatus.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'];
    final expireAt = json['expireAt'];
    final dailyMessages = json['dailyMessages'];
    return MembershipStatus(
      isMember: json['isMember'] == true,
      plan: plan is String ? plan : null,
      expireAt: expireAt is int ? expireAt : null,
      contextLimit: (json['contextLimit'] as num?)?.toInt() ?? 128000,
      dailyMessages: dailyMessages is int ? dailyMessages : null,
    );
  }
}

class CreateOrderResult {
  const CreateOrderResult({required this.qrcode, required this.tradeNo});

  final String qrcode;
  final String tradeNo;

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) =>
      CreateOrderResult(
        qrcode: json['qrcode'] as String,
        tradeNo: json['trade_no'] as String,
      );
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
