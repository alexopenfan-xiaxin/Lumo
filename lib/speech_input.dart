import 'package:flutter/services.dart';

class SpeechInput {
  static const _channel = MethodChannel('app.lumo.companion/speech');

  Future<String> start() async =>
      (await _channel.invokeMethod<String>('start'))?.trim() ?? '';

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> speak(String text) =>
      _channel.invokeMethod<void>('speak', {'text': text});

  Future<void> stopSpeaking() => _channel.invokeMethod<void>('stopSpeaking');
}
