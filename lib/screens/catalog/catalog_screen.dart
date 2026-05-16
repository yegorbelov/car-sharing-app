import 'package:flutter/material.dart';

class _DemoCar {
  const _DemoCar({
    required this.title,
    required this.subtitle,
    required this.pricePerDay,
    required this.rating,
  });

  final String title;
  final String subtitle;
  final String pricePerDay;
  final String rating;
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const List<_DemoCar> _cars = [
    _DemoCar(
      title: 'Toyota Camry',
      subtitle: 'Moscow · sedan',
      pricePerDay: '\$80 / day',
      rating: '4.8',
    ),
    _DemoCar(
      title: 'Kia Rio',
      subtitle: 'Saint Petersburg · economy',
      pricePerDay: '\$60 / day',
      rating: '4.5',
    ),
    _DemoCar(
      title: 'BMW X3',
      subtitle: 'Kazan · SUV',
      pricePerDay: '\$140 / day',
      rating: '4.9',
    ),
    _DemoCar(
      title: 'Lada Vesta',
      subtitle: 'Nizhny Novgorod · comfort',
      pricePerDay: '\$50 / day',
      rating: '4.3',
    ),
    _DemoCar(
      title: 'Mercedes-Benz E-Class',
      subtitle: 'Moscow · business',
      pricePerDay: '\$183 / day',
      rating: '4.7',
    ),
  ];

  final List<String> _chipLabels = const [
    'City',
    'Price',
    'Dates',
    'Class',
  ];

  int? _selectedChipIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            floating: true,
            title: const Text('Catalog'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'City, model…',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_chipLabels.length, (i) {
                      final selected = _selectedChipIndex == i;
                      return FilterChip(
                        label: Text(_chipLabels[i]),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedChipIndex = selected ? null : i;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.separated(
              itemCount: _cars.length,
              separatorBuilder: (_, unused) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c = _cars[index];
                return Material(
                  color: cs.surfaceContainerLowest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primaryContainer,
                                  cs.tertiaryContainer,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const SizedBox(
                              width: 76,
                              height: 76,
                              child: Icon(Icons.directions_car_rounded, size: 36),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 20, color: cs.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.rating,
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        c.pricePerDay,
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: cs.onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
