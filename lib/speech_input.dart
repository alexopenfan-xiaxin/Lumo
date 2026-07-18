import 'package:flutter/services.dart';

class SpeechInput {
  static const _channel = MethodChannel('app.lumo.companion/speech');

  Future<String> listen() async => (await _channel.invokeMethod<String>('listen'))?.trim() ?? '';
}
