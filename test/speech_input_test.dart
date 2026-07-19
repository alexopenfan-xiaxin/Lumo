import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/speech_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the Android speech channel contract', () async {
    const channel = MethodChannel('app.lumo.companion/speech');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'start' ? '  你好  ' : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final speech = SpeechInput();
    expect(await speech.start(), '你好');
    await speech.stop();
    await speech.speak('语音回复');
    await speech.stopSpeaking();

    expect(calls.map((call) => call.method), [
      'start',
      'stop',
      'speak',
      'stopSpeaking',
    ]);
    expect(calls.map((call) => call.arguments), [
      null,
      null,
      {'text': '语音回复'},
      null,
    ]);
  });
}
