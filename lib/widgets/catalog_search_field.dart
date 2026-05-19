import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/vehicle.dart';

class CatalogSearchSuggestion {
  const CatalogSearchSuggestion({
    required this.label,
    required this.insertText,
    this.subtitle,
    this.icon = Icons.search_rounded,
  });

  final String label;
  final String insertText;
  final String? subtitle;
  final IconData icon;
}

List<CatalogSearchSuggestion> buildCatalogSearchSuggestions(
  List<Vehicle> vehicles,
  String query,
) {
  if (vehicles.isEmpty) return const [];

  final q = query.trim().toLowerCase();

  if (q.isEmpty) {
    final suggestions = <CatalogSearchSuggestion>[];
    final cityCounts = <String, int>{};
    for (final v in vehicles) {
      cityCounts[v.city] = (cityCounts[v.city] ?? 0) + 1;
    }
    final cities = cityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in cities.take(5)) {
      suggestions.add(
        CatalogSearchSuggestion(
          label: e.key,
          subtitle: '${e.value} ${e.value == 1 ? 'car' : 'cars'}',
          insertText: e.key,
          icon: Icons.location_city_outlined,
        ),
      );
    }

    final seenTitles = <String>{};
    for (final v in vehicles) {
      if (seenTitles.add(v.title)) {
        suggestions.add(
          CatalogSearchSuggestion(
            label: v.title,
            subtitle: v.catalogLocationLabel,
            insertText: v.title,
            icon: Icons.directions_car_outlined,
          ),
        );
      }
      if (seenTitles.length >= 10) break;
    }
    return suggestions;
  }

  final scored = <({CatalogSearchSuggestion s, int score})>[];

  void addMatch({
    required String label,
    required String insertText,
    required String haystack,
    String? subtitle,
    required IconData icon,
    int baseScore = 0,
  }) {
    final h = haystack.toLowerCase();
    if (!h.contains(q)) return;
    var score = baseScore;
    if (h.startsWith(q)) score += 4;
    if (label.toLowerCase() == q) score += 3;
    scored.add((
      s: CatalogSearchSuggestion(
        label: label,
        insertText: insertText,
        subtitle: subtitle,
        icon: icon,
      ),
      score: score,
    ));
  }

  final seen = <String>{};
  for (final v in vehicles) {
    if (seen.add('city:${v.city}')) {
      addMatch(
        label: v.city,
        insertText: v.city,
        haystack: v.city,
        subtitle: 'City',
        icon: Icons.location_on_outlined,
        baseScore: 5,
      );
    }
    if (seen.add('title:${v.title}')) {
      addMatch(
        label: v.title,
        insertText: v.title,
        haystack: '${v.title} ${v.city}',
        subtitle: v.catalogLocationLabel,
        icon: Icons.directions_car_outlined,
        baseScore: 6,
      );
    }
    if (v.modelYear > 0 && seen.add('year:${v.modelYear}')) {
      final y = '${v.modelYear}';
      addMatch(
        label: y,
        insertText: y,
        haystack: y,
        subtitle: 'Model year',
        icon: Icons.calendar_today_outlined,
        baseScore: 4,
      );
    }
    final classLabel = _classLabel(v.className);
    if (seen.add('class:${v.className}')) {
      addMatch(
        label: classLabel,
        insertText: classLabel,
        haystack: '${v.className} $classLabel',
        subtitle: 'Class',
        icon: Icons.category_outlined,
        baseScore: 3,
      );
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(12).map((e) => e.s).toList();
}

String _classLabel(String c) => switch (c.toLowerCase()) {
  'sedan' => 'Sedan',
  'suv' => 'SUV',
  'economy' => 'Economy',
  'comfort' => 'Comfort',
  'business' => 'Business',
  _ => c,
};

/// Search bar for catalog — reports [onSearchModeChanged] when entering search screen.
class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.searchActive,
    required this.onSearchModeChanged,
    required this.onQueryChanged,
    this.onSortTap,
  });

  final TextEditingController controller;
  final bool searchActive;
  final ValueChanged<bool> onSearchModeChanged;
  final VoidCallback onQueryChanged;
  final VoidCallback? onSortTap;

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant CatalogSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchActive && !widget.searchActive) {
      _focus.unfocus();
    } else if (!oldWidget.searchActive && widget.searchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
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
    if (_focus.hasFocus && !widget.searchActive) {
      widget.onSearchModeChanged(true);
    }
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  void _exitSearch() {
    _focus.unfocus();
    widget.onSearchModeChanged(false);
  }

  void _clear() {
    widget.controller.clear();
    widget.onQueryChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.isNotEmpty;
    final active = widget.searchActive;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, active ? 8 : 16, active ? 8 : 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? cs.primary : const Color(0xFFE2E6EF),
            width: active ? 1.5 : 1,
          ),
          boxShadow: [
            if (!active)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            if (active)
              IconButton(
                onPressed: _exitSearch,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              )
            else
              const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  cs.onSurfaceVariant.withValues(alpha: 0.8),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: active,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'City, model, or year…',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => widget.onQueryChanged(),
                onSubmitted: (_) => _exitSearch(),
              ),
            ),
            if (hasText)
              IconButton(
                onPressed: _clear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                tooltip: 'Clear',
              ),
            if (!active && widget.onSortTap != null) ...[
              Container(width: 1, height: 28, color: const Color(0xFFE2E6EF)),
              IconButton(
                onPressed: widget.onSortTap,
                tooltip: 'Sort',
                icon: Icon(Icons.swap_vert_rounded, color: cs.onSurfaceVariant),
              ),
            ] else if (!active)
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Full-screen suggestion list shown while search is active.
class CatalogSearchSuggestionsView extends StatelessWidget {
  const CatalogSearchSuggestionsView({
    super.key,
    required this.vehicles,
    required this.query,
    required this.onPick,
  });

  final List<Vehicle> vehicles;
  final String query;
  final ValueChanged<CatalogSearchSuggestion> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suggestions = buildCatalogSearchSuggestions(vehicles, query);

    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            query.trim().isEmpty
                ? 'Start typing to search the catalog'
                : 'No matches for “${query.trim()}”',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
      itemBuilder: (context, i) {
        final s = suggestions[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, size: 20, color: cs.primary),
          ),
          title: _HighlightedText(
            text: s.label,
            highlight: query.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: s.subtitle != null
              ? Text(
                  s.subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
              : null,
          trailing: Icon(
            Icons.north_west_rounded,
            size: 18,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          onTap: () => onPick(s),
        );
      },
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlight,
    this.style,
  });

  final String text;
  final String highlight;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = highlight.trim().toLowerCase();
    if (h.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lower = text.toLowerCase();
    final i = lower.indexOf(h);
    if (i < 0) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style?.copyWith(color: cs.onSurface),
        children: [
          if (i > 0) TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + h.length),
            style: style?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (i + h.length < text.length)
            TextSpan(text: text.substring(i + h.length)),
        ],
      ),
    );
  }
}
