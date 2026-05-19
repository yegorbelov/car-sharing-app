import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/login_screen.dart';
import '../bookings/bookings_screen.dart';
import '../catalog/catalog_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onSignedOut,
    this.onSignedIn,
    this.isGuest = false,
  });

  final VoidCallback onSignedOut;
  final VoidCallback? onSignedIn;
  final bool isGuest;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _openCatalog() => setState(() => _selectedIndex = 0);

  void _openBookings() => setState(() => _selectedIndex = 1);

  void _onDestinationSelected(int index) {
    if (widget.isGuest && index != 0) {
      _promptSignIn();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _promptSignIn() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _GuestSignInSheet(),
    );

    if (proceed != true || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onSignedIn: () {
            Navigator.of(context).pop();
            widget.onSignedIn?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CatalogScreen(
            tabVisible: _selectedIndex == 0,
            onSignedIn: widget.onSignedIn,
            onBookingCreated: widget.isGuest ? null : _openBookings,
          ),
          if (widget.isGuest)
            const SizedBox.shrink()
          else
            BookingsScreen(
              onOpenCatalog: _openCatalog,
              tabVisible: _selectedIndex == 1,
            ),
          if (widget.isGuest)
            const SizedBox.shrink()
          else
            WalletScreen(tabVisible: _selectedIndex == 2),
          if (widget.isGuest)
            const SizedBox.shrink()
          else
            ProfileScreen(onSignedOut: widget.onSignedOut),
        ],
      ),
      bottomNavigationBar: _CustomTabBar(
        selectedIndex: _selectedIndex,
        onTap: _onDestinationSelected,
      ),
    );
  }
}

class _CustomTabBar extends StatelessWidget {
  const _CustomTabBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _AnimatedTabButton(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Catalog',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _AnimatedTabButton(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note_rounded,
                label: 'Bookings',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _AnimatedTabButton(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _AnimatedTabButton(
                svgIcon: 'assets/icons/profile.svg',
                label: 'Profile',
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTabButton extends StatefulWidget {
  const _AnimatedTabButton({
    this.icon,
    this.activeIcon,
    this.svgIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;
  final IconData? activeIcon;
  final String? svgIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AnimatedTabButton> createState() => _AnimatedTabButtonState();
}

class _AnimatedTabButtonState extends State<_AnimatedTabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _lift = Tween<double>(
      begin: 0.0,
      end: -3.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    if (widget.selected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedTabButton old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final color = ColorTween(
              begin: cs.onSurfaceVariant,
              end: cs.primary,
            ).evaluate(_ctrl)!;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, _lift.value),
                  child: Transform.scale(
                    scale: _scale.value,
                    child: widget.svgIcon != null
                        ? SvgPicture.asset(
                            widget.svgIcon!,
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              color,
                              BlendMode.srcIn,
                            ),
                          )
                        : Icon(
                            widget.selected
                                ? (widget.activeIcon ?? widget.icon!)
                                : widget.icon!,
                            size: 22,
                            color: color,
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: color,
                    height: 1.1,
                  ),
                  child: Text(widget.label),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GuestSignInSheet extends StatelessWidget {
  const _GuestSignInSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/profile.svg',
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(
                    cs.onPrimaryContainer,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to continue',
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a free account to book cars,\nmanage bookings, and more.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Continue as guest'),
          ),
        ],
      ),
    );
  }
}
