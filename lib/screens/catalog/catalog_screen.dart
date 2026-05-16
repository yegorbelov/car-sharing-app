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
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'City, model…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
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
          const SizedBox(height: 16),
          ..._cars.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(Icons.directions_car, size: 36),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(c.rating),
                                  const Spacer(),
                                  Text(
                                    c.pricePerDay,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
