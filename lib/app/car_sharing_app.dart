import 'package:flutter/material.dart';

import '../core/auth_storage.dart';
import '../screens/home/home.dart';
import '../services/auth_api.dart';
import '../services/deals_api.dart';
import '../services/vehicles_api.dart';
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
    DealsApi.onUnauthorized = _forceSignOut;
    AuthApi.onUnauthorized = _forceSignOut;
    VehiclesApi.onUnauthorized = _forceSignOut;
    _restore();
  }

  @override
  void dispose() {
    DealsApi.onUnauthorized = null;
    AuthApi.onUnauthorized = null;
    VehiclesApi.onUnauthorized = null;
    super.dispose();
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

  void _forceSignOut() {
    if (!mounted) return;
    AuthStorage.clear();
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
          : HomePage(
              onSignedOut: _onSignedOut,
              onSignedIn: _onSignedIn,
              isGuest: !_signedIn,
            ),
    );
  }
}
