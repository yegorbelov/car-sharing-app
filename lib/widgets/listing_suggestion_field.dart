import 'package:flutter/material.dart';

import 'app_input.dart';

/// Text field with inline suggestions (filtered as the user types).
class ListingSuggestionField extends StatefulWidget {
  const ListingSuggestionField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.labelText,
    this.hintText,
    this.icon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String labelText;
  final String? hintText;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;

  @override
  State<ListingSuggestionField> createState() => _ListingSuggestionFieldState();
}

class _ListingSuggestionFieldState extends State<ListingSuggestionField> {
  final _focus = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(ListingSuggestionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      setState(() => _showSuggestions = true);
    } else {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted && !_focus.hasFocus) {
          setState(() => _showSuggestions = false);
        }
      });
    }
  }

  void _onTextChange() {
    if (_focus.hasFocus) setState(() {});
  }

  List<String> get _filtered {
    final q = widget.controller.text.trim().toLowerCase();
    final source = widget.suggestions;
    if (q.isEmpty) return source.take(8).toList();
    final starts = <String>[];
    final contains = <String>[];
    for (final s in source) {
      final lower = s.toLowerCase();
      if (lower.startsWith(q)) {
        starts.add(s);
      } else if (lower.contains(q)) {
        contains.add(s);
      }
    }
    return [...starts, ...contains].take(8).toList();
  }

  void _applySuggestion(String value) {
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _showSuggestions = false);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final visible = _showSuggestions && filtered.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          textCapitalization: widget.textCapitalization,
          decoration: AppInputs.decoration(
            context,
            labelText: widget.labelText,
            hintText: widget.hintText,
            icon: widget.icon,
            suffixIcon: widget.suffixIcon,
          ),
          validator: widget.validator,
          onTap: () => setState(() => _showSuggestions = true),
        ),
        if (visible) ...[
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    InkWell(
                      onTap: () => _applySuggestion(filtered[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.icon ?? Icons.search_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                filtered[i],
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Builds city and vehicle title suggestion lists for the listing form.
abstract final class ListingFormSuggestions {
  static const defaultCities = [
    'Moscow',
    'Saint Petersburg',
    'Kazan',
    'Sochi',
    'Nizhny Novgorod',
    'Yekaterinburg',
    'Novosibirsk',
    'Krasnodar',
  ];

  static const popularTitles = [
    'Toyota Camry',
    'Toyota Corolla',
    'Toyota RAV4',
    'BMW 3 Series',
    'BMW X3',
    'BMW X5',
    'Mercedes-Benz C-Class',
    'Mercedes-Benz E-Class',
    'Audi A4',
    'Audi Q5',
    'Volkswagen Polo',
    'Volkswagen Tiguan',
    'Hyundai Tucson',
    'Hyundai Solaris',
    'Kia Rio',
    'Kia Sportage',
    'Lada Vesta',
    'Lada Granta',
    'Tesla Model 3',
    'Tesla Model Y',
    'Skoda Octavia',
    'Renault Duster',
  ];

  static List<String> citiesFromCatalog(Iterable<String> catalogCities) {
    return _merge(defaultCities, catalogCities);
  }

  static List<String> titlesFromCatalog(Iterable<String> catalogTitles) {
    return _merge(popularTitles, catalogTitles);
  }

  static List<String> _merge(List<String> base, Iterable<String> extra) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in [...base, ...extra]) {
      final t = s.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (seen.add(key)) out.add(t);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }
}
