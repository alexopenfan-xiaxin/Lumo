import 'package:flutter/material.dart';

import 'shell.dart';
import 'theme.dart';

class LumoApp extends StatefulWidget {
  const LumoApp({super.key});

  @override
  State<LumoApp> createState() => _LumoAppState();
}

class _LumoAppState extends State<LumoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lumo',
    debugShowCheckedModeBanner: false,
    theme: buildLumoTheme(Brightness.light),
    darkTheme: buildLumoTheme(Brightness.dark),
    themeMode: _themeMode,
    home: LumoShell(
      themeMode: _themeMode,
      onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
    ),
  );
}

