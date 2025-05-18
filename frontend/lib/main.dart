import 'package:flutter/material.dart';
import 'package:frontend/auth.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blockchain Instagram',
      theme: ThemeData.dark().copyWith(
          primaryColor: Colors.cyanAccent,
          scaffoldBackgroundColor: Colors.black),
      home: AuthPage(),
    );
  }
}
