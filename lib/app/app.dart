import 'package:flutter/material.dart';
import 'package:synclip/app/theme/theme.dart';
import 'package:synclip/features/onboarding/presentation/welcome_screen.dart';

class SynclipApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synclip',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const WelcomeScreen(),
    );
  }
}
