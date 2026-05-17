import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _submitting = false;
  String? _photoPath;

  static const _classOptions = ['sedan', 'suv', 'economy', 'comfort', 'business'];
  String _selectedClass = 'sedan';

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _classCtrl.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _photoPath = picked.path);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    setState(() => _submitting = true);
    try {
      final result = await VehiclesApi.createListing(
        title: _title.text,
        city: _city.text,
        className: _selectedClass,
        pricePerDay: price,
      );
      if (!context.mounted) return;

      // Upload photo if one was picked.
      final vehicleId = result['id'] as int?;
      if (_photoPath != null && vehicleId != null) {
        try {
          await VehiclesApi.uploadVehiclePhoto(vehicleId: vehicleId, filePath: _photoPath!);
        } catch (_) {
          // Photo upload failure is non-fatal — listing still created.
        }
      }

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Photo picker ────────────────────────────────────────────
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photoPath != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_photoPath!), fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _photoHint(cs)),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: _editBadge(cs),
                          ),
                        ],
                      )
                    : _photoHint(cs),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Tell renters about your car',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Your listing will appear in the catalog.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vehicle make & model',
                hintText: 'e.g. Toyota Camry 2022',
                prefixIcon: Icon(Icons.directions_car_outlined),
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
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Class selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle class',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _classOptions.map((c) => ChoiceChip(
                    label: Text(_classLabel(c)),
                    selected: _selectedClass == c,
                    onSelected: (_) => setState(() => _selectedClass = c),
                  )).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price per day (USD)',
                hintText: 'e.g. 75',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final p = double.tryParse(v.trim().replaceAll(',', '.'));
                if (p == null || p <= 0) return 'Enter a valid price';
                return null;
              },
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _submitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Publish listing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoHint(ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 42, color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
        const SizedBox(height: 8),
        Text(
          'Tap to add a photo',
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
        ),
        Text(
          'Optional — helps renters find your car',
          style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _editBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_rounded, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text('Change', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _classLabel(String c) => switch (c) {
        'sedan' => 'Sedan',
        'suv' => 'SUV',
        'economy' => 'Economy',
        'comfort' => 'Comfort',
        'business' => 'Business',
        _ => c,
      };
}
