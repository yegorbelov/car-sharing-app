import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api_config.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_input.dart';
import '../../services/vehicles_api.dart';
import 'vehicle_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.tabVisible, this.onSignedIn});

  final bool tabVisible;
  final VoidCallback? onSignedIn;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  static const _classLabels = [
    'All',
    'Sedan',
    'SUV',
    'Economy',
    'Comfort',
    'Business',
  ];
  static const _classValues = <String?>[
    null,
    'sedan',
    'suv',
    'economy',
    'comfort',
    'business',
  ];
  String? _selectedClass;

  @override
  void didUpdateWidget(CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabVisible && !oldWidget.tabVisible) _load();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Vehicle> get _filteredVehicles {
    var list = _vehicles;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (v) =>
                '${v.title} ${v.city} ${v.className}'.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_selectedClass != null) {
      list = list
          .where((v) => v.className.toLowerCase() == _selectedClass)
          .toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await VehiclesApi.fetchRaw();
      if (!mounted) return;
      setState(() {
        _vehicles = raw.map((e) => Vehicle.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _scrolled = false;

  void _onScroll() {
    final scrolled = _scrollCtrl.hasClients && _scrollCtrl.offset > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _filteredVehicles;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surface,
            elevation: _scrolled ? 1 : 0,
            shadowColor: Colors.black26,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 6),
                    child: Text(
                      'Catalog',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  _CatalogSearchBar(
                    controller: _searchCtrl,
                    classLabels: _classLabels,
                    classValues: _classValues,
                    selectedClass: _selectedClass,
                    onChipTap: (String? value) {
                      setState(() {
                        final isSelected = _selectedClass == value;
                        _selectedClass = isSelected ? null : value;
                      });
                    },
                    onQueryChanged: () => setState(() {}),
                  ),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                controller: _scrollCtrl,
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _buildContentSlivers(context, cs, visible),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    ColorScheme cs,
    List<Vehicle> visible,
  ) {
    if (_loading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load catalog.\nCheck your connection.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _vehicles.isEmpty
                        ? 'No vehicles available.'
                        : 'No cars match your search.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final c = visible[index];
            return _VehicleCard(
              vehicle: c,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehicleDetailScreen(
                    vehicle: c,
                    onSignedIn: widget.onSignedIn,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _CatalogSearchBar extends StatelessWidget {
  const _CatalogSearchBar({
    required this.controller,
    required this.classLabels,
    required this.classValues,
    required this.selectedClass,
    required this.onChipTap,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final List<String> classLabels;
  final List<String?> classValues;
  final String? selectedClass;
  final ValueChanged<String?> onChipTap;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: TextField(
            controller: controller,
            decoration: AppInputs.search(
              context,
              hintText: 'City, model…',
              icon: Icon(Icons.search_rounded, size: 22, color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
            ),
            onChanged: (_) => onQueryChanged(),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < classLabels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  FilterChip(
                    label: Text(classLabels[i]),
                    selected: selectedClass == classValues[i],
                    onSelected: (_) => onChipTap(classValues[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Vehicle card photo (swipeable when multiple images) ───────────────────

class _VehicleCardPhotoStack extends StatefulWidget {
  const _VehicleCardPhotoStack({required this.vehicle, required this.cs});

  final Vehicle vehicle;
  final ColorScheme cs;

  @override
  State<_VehicleCardPhotoStack> createState() => _VehicleCardPhotoStackState();
}

class _VehicleCardPhotoStackState extends State<_VehicleCardPhotoStack> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _VehicleCardPhotoStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrls = oldWidget.vehicle.galleryUrls.join('|');
    final newUrls = widget.vehicle.galleryUrls.join('|');
    if (oldUrls != newUrls) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final cs = widget.cs;
    final urls = vehicle.galleryUrls.map(fullImageUrl).toList();
    final hasPhoto = urls.isNotEmpty;
    final multi = urls.length > 1;

    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!hasPhoto)
            _CardPhotoPlaceholder(cs: cs)
          else if (!multi)
            Image.network(
              urls.first,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _CardPhotoPlaceholder(cs: cs),
            )
          else
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemCount: urls.length,
              itemBuilder: (context, i) => Image.network(
                urls[i],
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    _CardPhotoPlaceholder(cs: cs),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _Pill(
              text: vehicle.className.isNotEmpty
                  ? vehicle.className[0].toUpperCase() +
                        vehicle.className.substring(1)
                  : '',
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/star.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    vehicle.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (multi)
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  final active = i == _pageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Text(
              vehicle.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vehicle card ───────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  static const _accentColor = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VehicleCardPhotoStack(vehicle: vehicle, cs: cs),

            // ── Info row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      vehicle.city,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\$${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({this.text, this.child});
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          child ??
          Text(
            text ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
    );
  }
}

class _CardPhotoPlaceholder extends StatelessWidget {
  const _CardPhotoPlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.directions_car_rounded,
        size: 64,
        color: cs.onPrimaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}
