import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//import tabbar from home/tabbar.dart
import 'tabbar.dart';

String get _apiBaseUrl {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:1323';
  }
  return 'http://localhost:1323';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _body;
  String? _error;
  bool _loading = true;

  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Text('Home'),
    const Text('Search'),
    const Text('Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _body = null;
    });
    final uri = Uri.parse('$_apiBaseUrl/');
    try {
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _body = response.body;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'HTTP ${response.statusCode}: ${response.body}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                )
              : SelectableText(
                  _body ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
