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

  final ChatStore _store;
  final String _endpoint;

  Future<AccountSession?> session() async {
    final saved = await _store.setting(_sessionKey);
    if (saved == null) return null;
    try {
      return AccountSession.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on FormatException {
      await _store.saveSetting(_sessionKey, null);
      return null;
    }
  }

  Future<RequestIdentity> identity() async {
    var guestId = await _store.setting(_guestKey);
    try {
      guestId = await const MethodChannel('app.lumo.companion/device').invokeMethod<String>('getId') ?? guestId;
    } on MissingPluginException {
      // Tests and non-Android hosts use the persisted random identifier below.
    } on PlatformException {
      // A platform identity failure must not prevent the guest experience.
    }
    if (guestId == null) {
      guestId = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    }
    await _store.saveSetting(_guestKey, guestId);
    return RequestIdentity(guestId: guestId, token: (await session())?.token);
  }

  Future<AccountSession> login(String username, String password) =>
      _authenticate('/auth/login', {'username': username, 'password': password});

  Future<AccountSession> register(String username, String password, String inviteCode) =>
      _authenticate('/auth/register', {'username': username, 'password': password, 'inviteCode': inviteCode});

  Future<void> logout() => _store.saveSetting(_sessionKey, null);

  Future<AccountSession> _authenticate(String path, Map<String, String> body) async {
    final response = await _post(path, body);
    final account = AccountSession.fromJson(response);
    await _store.saveSetting(_sessionKey, jsonEncode(account.toJson()));
    return account;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> body) async {
    if (_endpoint.isEmpty) throw const AuthException('账号服务还没有部署完成。');
    final endpoint = Uri.parse(_endpoint);
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint.replace(path: path, query: null));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final decoded = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      if (response.statusCode != HttpStatus.ok) throw AuthException(decoded['error'] as String? ?? '账号操作失败，请稍后再试。');
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
  const AccountSession({required this.username, required this.token, required this.isMember, required this.role});

  final String username;
  final String token;
  final bool isMember;
  final String role;

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
        username: json['username']! as String,
        token: json['token']! as String,
        isMember: json['isMember'] == true,
        role: json['role']! as String,
      );

  Map<String, dynamic> toJson() => {'username': username, 'token': token, 'isMember': isMember, 'role': role};
}

class RequestIdentity {
  const RequestIdentity({required this.guestId, required this.token});

  final String guestId;
  final String? token;
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
