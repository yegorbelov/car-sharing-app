import 'package:flutter/material.dart';

// ignore_for_file: use_build_context_synchronously

import '../../services/vehicles_api.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _classCtrl = TextEditingController();
  final _price = TextEditingController();
  final _rating = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _classCtrl.dispose();
    _price.dispose();
    _rating.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) return;
    double? rating;
    final rText = _rating.text.trim();
    if (rText.isNotEmpty) {
      rating = double.tryParse(rText.replaceAll(',', '.'));
    }
    setState(() => _submitting = true);
    try {
      await VehiclesApi.createListing(
        title: _title.text,
        city: _city.text,
        className: _classCtrl.text,
        pricePerDay: price,
        rating: rating,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (context.mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your listing will appear in the catalog for renters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vehicle title',
                hintText: 'e.g. Toyota Camry 2020',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'e.g. Moscow',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _classCtrl,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Class',
                hintText: 'sedan, SUV, economy…',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price per day (USD)',
                hintText: 'e.g. 75',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final p = double.tryParse(v.trim().replaceAll(',', '.'));
                if (p == null || p <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _rating,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rating (optional)',
                hintText: '1.0–5.0, default 4.5',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final r = double.tryParse(v.trim().replaceAll(',', '.'));
                if (r == null || r < 1 || r > 5) return 'Between 1 and 5';
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish listing'),
            ),
          ],
        ),
      ),
    );
  }
}
