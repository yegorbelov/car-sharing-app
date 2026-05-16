import 'package:flutter/material.dart';

import '../core/auth_storage.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home.dart';
import 'theme.dart';

class CarSharingApp extends StatefulWidget {
  const CarSharingApp({super.key});

  @override
  State<CarSharingApp> createState() => _CarSharingAppState();
}

class _CarSharingAppState extends State<CarSharingApp> {
  bool _ready = false;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final has = await AuthStorage.hasSession();
    if (!mounted) return;
    setState(() {
      _signedIn = has;
      _ready = true;
    });
  }

  void _onSignedIn() {
    setState(() => _signedIn = true);
  }

  void _onSignedOut() {
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Sharing',
      theme: buildAppTheme(),
      home: !_ready
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _signedIn
              ? HomePage(onSignedOut: _onSignedOut)
              : LoginScreen(onSignedIn: _onSignedIn),
    );
  }
}
