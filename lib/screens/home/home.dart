import 'package:flutter/material.dart';

import '../bookings/bookings_screen.dart';
import '../catalog/catalog_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _openCatalog() {
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CatalogScreen(tabVisible: _selectedIndex == 0),
          BookingsScreen(onOpenCatalog: _openCatalog, tabVisible: _selectedIndex == 1),
          WalletScreen(tabVisible: _selectedIndex == 2),
          ProfileScreen(onSignedOut: widget.onSignedOut),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
