import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_store.dart';
import 'shell.dart';
import 'splash_screen.dart';
import 'theme.dart';

class LumoApp extends StatefulWidget {
  const LumoApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  State<LumoApp> createState() => _LumoAppState();
}

class _LumoAppState extends State<LumoApp> {
  static const _themeModeKey = 'theme_mode';

  final _store = ChatStore();
  late final Future<void> _themeReady;
  ThemeMode _themeMode = ThemeMode.system;
  bool _shellReady = false;
  late bool _splashFinished;

  @override
  void initState() {
    super.initState();
    _splashFinished = !widget.showSplash;
    _themeReady = _loadThemeMode();
    unawaited(_themeReady);
  }

  Future<void> _loadThemeMode() async {
    final mode = themeModeFromSetting(await _store.setting(_themeModeKey));
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    await _themeReady;
    await _store.saveSetting(_themeModeKey, mode.name);
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lumo',
    debugShowCheckedModeBanner: false,
    theme: buildLumoTheme(Brightness.light),
    darkTheme: buildLumoTheme(Brightness.dark),
    themeMode: _themeMode,
    home: Builder(
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: dark
                    ? const Color(0xFF171513)
                    : const Color(0xFFF8F5F0),
              ),
          child: Stack(
            children: [
              LumoShell(
                themeMode: _themeMode,
                onThemeModeChanged: _changeThemeMode,
                onReady: () {
                  if (!_shellReady) setState(() => _shellReady = true);
                },
              ),
              if (!_splashFinished)
                Positioned.fill(
                  child: LumoSplash(
                    ready: _shellReady,
                    onFinished: () => setState(() => _splashFinished = true),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

ThemeMode themeModeFromSetting(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};
