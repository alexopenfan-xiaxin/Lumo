import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  ThemeMode _themeMode = ThemeMode.light;
  bool _shellReady = false;
  late bool _splashFinished;

  @override
  void initState() {
    super.initState();
    _splashFinished = !widget.showSplash;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lumo',
        debugShowCheckedModeBanner: false,
        theme: buildLumoTheme(Brightness.light),
        darkTheme: buildLumoTheme(Brightness.dark),
        themeMode: _themeMode,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: (_themeMode == ThemeMode.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _themeMode == ThemeMode.dark
                ? const Color(0xFF171513)
                : const Color(0xFFF8F5F0),
          ),
          child: Stack(
            children: [
              LumoShell(
                themeMode: _themeMode,
                onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
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
        ),
      );
}
