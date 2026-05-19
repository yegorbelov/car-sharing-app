import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api_config.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_input.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../../services/vehicles_api.dart';
import 'vehicle_detail_screen.dart';

enum CatalogSort {
  relevance('Relevance'),
  newest('Newest'),
  oldest('Oldest'),
  ratingHigh('Highest rated'),
  ratingLow('Lowest rated'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  reviewsMost('Most reviewed');

  const CatalogSort(this.label);
  final String label;
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.tabVisible,
    this.onSignedIn,
    this.onBookingCreated,
  });

  final bool tabVisible;
  final VoidCallback? onSignedIn;
  final VoidCallback? onBookingCreated;

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
  int? _minModelYear;
  int? _maxModelYear;
  CatalogSort _sort = CatalogSort.relevance;

  int get _selectedClassIndex {
    for (var i = 0; i < _classValues.length; i++) {
      if (_classValues[i] == _selectedClass) return i;
    }
    return 0;
  }

  String? get _yearFilterSummary {
    if (_minModelYear == null && _maxModelYear == null) return null;
    if (_minModelYear != null && _maxModelYear != null) {
      return '$_minModelYear–$_maxModelYear';
    }
    if (_minModelYear != null) return 'from $_minModelYear';
    return 'to $_maxModelYear';
  }

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
    var list = List<Vehicle>.from(_vehicles);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (v) =>
                '${v.title} ${v.city} ${v.className} ${v.modelYear}'
                    .toLowerCase()
                    .contains(q),
          )
          .toList();
    }
    if (_selectedClass != null) {
      list = list
          .where((v) => v.className.toLowerCase() == _selectedClass)
          .toList();
    }
    if (_minModelYear != null || _maxModelYear != null) {
      list = list.where((v) {
        if (v.modelYear <= 0) return false;
        if (_minModelYear != null && v.modelYear < _minModelYear!) return false;
        if (_maxModelYear != null && v.modelYear > _maxModelYear!) return false;
        return true;
      }).toList();
    }
    return _sortVehicles(list, q);
  }

  List<Vehicle> _sortVehicles(List<Vehicle> list, String queryLower) {
    int relevanceScore(Vehicle v) {
      if (queryLower.isEmpty) return 0;
      final hay = '${v.title} ${v.city} ${v.className}'.toLowerCase();
      var score = 0;
      if (hay.startsWith(queryLower)) score += 4;
      if (hay.contains(queryLower)) score += 2;
      return score;
    }

    double relevanceRank(Vehicle v) =>
        v.rating * (1 + (v.reviewCount / 80).clamp(0.0, 3.0));

    int compareCreated(Vehicle a, Vehicle b, {required bool newestFirst}) {
      final da = a.createdAtDate;
      final db = b.createdAtDate;
      if (da == null && db == null) {
        return newestFirst ? b.id.compareTo(a.id) : a.id.compareTo(b.id);
      }
      if (da == null) return 1;
      if (db == null) return -1;
      return newestFirst ? db.compareTo(da) : da.compareTo(db);
    }

    switch (_sort) {
      case CatalogSort.relevance:
        list.sort((a, b) {
          final rs = relevanceScore(b).compareTo(relevanceScore(a));
          if (rs != 0) return rs;
          final rr = relevanceRank(b).compareTo(relevanceRank(a));
          if (rr != 0) return rr;
          return b.reviewCount.compareTo(a.reviewCount);
        });
      case CatalogSort.newest:
        list.sort((a, b) => compareCreated(a, b, newestFirst: true));
      case CatalogSort.oldest:
        list.sort((a, b) => compareCreated(a, b, newestFirst: false));
      case CatalogSort.ratingHigh:
        list.sort((a, b) {
          final r = b.rating.compareTo(a.rating);
          if (r != 0) return r;
          return b.reviewCount.compareTo(a.reviewCount);
        });
      case CatalogSort.ratingLow:
        list.sort((a, b) {
          final r = a.rating.compareTo(b.rating);
          if (r != 0) return r;
          return a.reviewCount.compareTo(b.reviewCount);
        });
      case CatalogSort.priceLow:
        list.sort(
          (a, b) => a.pricePerDayCents.compareTo(b.pricePerDayCents),
        );
      case CatalogSort.priceHigh:
        list.sort(
          (a, b) => b.pricePerDayCents.compareTo(a.pricePerDayCents),
        );
      case CatalogSort.reviewsMost:
        list.sort((a, b) {
          final c = b.reviewCount.compareTo(a.reviewCount);
          if (c != 0) return c;
          return b.rating.compareTo(a.rating);
        });
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<CatalogSort>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'Sort by',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final option in CatalogSort.values)
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(option.label),
                  trailing: _sort == option
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != _sort) {
      setState(() => _sort = picked);
    }
  }

  ({int min, int max}) _modelYearBounds() {
    final years = _vehicles
        .where((v) => v.modelYear > 0)
        .map((v) => v.modelYear)
        .toList();
    if (years.isEmpty) {
      final y = DateTime.now().year;
      return (min: y - 15, max: y);
    }
    years.sort();
    return (min: years.first, max: years.last);
  }

  Future<void> _showYearFilterSheet() async {
    final bounds = _modelYearBounds();
    var range = RangeValues(
      (_minModelYear ?? bounds.min).toDouble(),
      (_maxModelYear ?? bounds.max).toDouble(),
    );
    var yearFilterOn = _minModelYear != null || _maxModelYear != null;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.5;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Text(
                    'Model year',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filter by year'),
                    value: yearFilterOn,
                    onChanged: (on) {
                      setSheetState(() {
                        yearFilterOn = on;
                        if (on) {
                          range = RangeValues(
                            bounds.min.toDouble(),
                            bounds.max.toDouble(),
                          );
                        }
                      });
                    },
                  ),
                  if (yearFilterOn) ...[
                    Text(
                      '${range.start.round()} – ${range.end.round()}',
                      style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RangeSlider(
                      values: range,
                      min: bounds.min.toDouble(),
                      max: bounds.max.toDouble(),
                      divisions: (bounds.max - bounds.min).clamp(1, 30),
                      labels: RangeLabels(
                        '${range.start.round()}',
                        '${range.end.round()}',
                      ),
                      onChanged: (v) => setSheetState(() => range = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: yearFilterOn
                            ? () => setSheetState(() => yearFilterOn = false)
                            : null,
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        if (yearFilterOn) {
          _minModelYear = range.start.round();
          _maxModelYear = range.end.round();
        } else {
          _minModelYear = null;
          _maxModelYear = null;
        }
      });
    }
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
                  _CatalogSearchBar(
                    controller: _searchCtrl,
                    onSortTap: _showSortSheet,
                    onQueryChanged: () => setState(() {}),
                  ),
                  _CatalogFilterStrip(
                    labels: _classLabels,
                    values: _classValues,
                    selectedIndex: _selectedClassIndex,
                    yearFilterActive:
                        _minModelYear != null || _maxModelYear != null,
                    yearFilterLabel: _yearFilterSummary,
                    onClassSelected: (value) {
                      setState(() {
                        final isSelected = _selectedClass == value;
                        _selectedClass = isSelected ? null : value;
                      });
                    },
                    onYearTap: _showYearFilterSheet,
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
      final noListings = _vehicles.isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: IllustratedEmptyState(
              assetPath: IllustratedEmptyState.catalogEmpty,
              title: noListings ? 'No cars yet' : 'Nothing found',
              subtitle: noListings
                  ? 'Check back soon — new listings appear here.'
                  : 'Try another city, model, or filter.',
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
                    onBookingCreated: widget.onBookingCreated,
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
    required this.onSortTap,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSortTap;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: TextField(
        controller: controller,
        decoration: AppInputs.search(
          context,
          hintText: 'City, model, year…',
          icon: Icon(
            Icons.search_rounded,
            size: 22,
            color: cs.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ).copyWith(
          suffixIcon: IconButton(
            onPressed: onSortTap,
            tooltip: 'Sort',
            icon: Icon(
              Icons.swap_vert_rounded,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        onChanged: (_) => onQueryChanged(),
      ),
    );
  }
}

/// Horizontal class filters with a sliding pill indicator.
class _CatalogFilterStrip extends StatefulWidget {
  const _CatalogFilterStrip({
    required this.labels,
    required this.values,
    required this.selectedIndex,
    required this.yearFilterActive,
    required this.yearFilterLabel,
    required this.onClassSelected,
    required this.onYearTap,
  });

  final List<String> labels;
  final List<String?> values;
  final int selectedIndex;
  final bool yearFilterActive;
  final String? yearFilterLabel;
  final ValueChanged<String?> onClassSelected;
  final VoidCallback onYearTap;

  @override
  State<_CatalogFilterStrip> createState() => _CatalogFilterStripState();
}

class _CatalogFilterStripState extends State<_CatalogFilterStrip> {
  final _scrollCtrl = ScrollController();
  final _trackKey = GlobalKey();
  final _chipKeys = <GlobalKey>[];

  double _indicatorLeft = 0;
  double _indicatorWidth = 0;
  bool _indicatorReady = false;

  @override
  void initState() {
    super.initState();
    _chipKeys.addAll(List.generate(widget.labels.length, (_) => GlobalKey()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicator());
  }

  @override
  void didUpdateWidget(covariant _CatalogFilterStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicator());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _syncIndicator() {
    if (!mounted) return;
    final trackBox =
        _trackKey.currentContext?.findRenderObject() as RenderBox?;
    final chipBox =
        _chipKeys[widget.selectedIndex].currentContext?.findRenderObject()
            as RenderBox?;
    if (trackBox == null || chipBox == null || !trackBox.hasSize) return;

    final chipGlobal = chipBox.localToGlobal(Offset.zero);
    final trackGlobal = trackBox.localToGlobal(Offset.zero);
    final left = chipGlobal.dx - trackGlobal.dx;
    final width = chipBox.size.width;

    setState(() {
      _indicatorLeft = left;
      _indicatorWidth = width;
      _indicatorReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    key: _trackKey,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: _indicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: _indicatorWidth,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _indicatorReady ? 1 : 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < widget.labels.length; i++)
                            _FilterChip(
                              key: _chipKeys[i],
                              label: widget.labels[i],
                              selected: i == widget.selectedIndex,
                              onTap: () =>
                                  widget.onClassSelected(widget.values[i]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _YearFilterChip(
            active: widget.yearFilterActive,
            summary: widget.yearFilterLabel,
            onTap: widget.onYearTap,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearFilterChip extends StatelessWidget {
  const _YearFilterChip({
    required this.active,
    required this.summary,
    required this.onTap,
  });

  final bool active;
  final String? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primary : const Color(0xFFE8ECF4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: active ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                summary ?? 'Year',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
            child: IgnorePointer(
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
          ),
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              child: _Pill(
              text: vehicle.className.isNotEmpty
                  ? vehicle.className[0].toUpperCase() +
                        vehicle.className.substring(1)
                  : '',
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: _RatingPill(
                rating: vehicle.rating,
                reviewCount: vehicle.reviewCount,
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
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
                  if (multi) ...[
                    const SizedBox(height: 8),
                    Row(
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
                  ],
                ],
              ),
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
                      vehicle.catalogLocationLabel,
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

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return _Pill(
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
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reviewCount > 0) ...[
            Text(
              ' · ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$reviewCount',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
