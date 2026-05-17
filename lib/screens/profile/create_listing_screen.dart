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
  final _mileage = TextEditingController();
  final _year = TextEditingController();
  final _engineCc = TextEditingController();
  final _color = TextEditingController();
  final _condition = TextEditingController();
  final _techNotes = TextEditingController();
  final _vin = TextEditingController();

  bool _submitting = false;
  final List<String> _photoPaths = [];

  static const _classOptions = ['sedan', 'suv', 'economy', 'comfort', 'business'];
  String _selectedClass = 'sedan';

  static const _transmissionOptions = ['automatic', 'manual', 'cvt', 'other'];
  String _selectedTransmission = 'automatic';

  static const _fuelOptions = ['petrol', 'diesel', 'electric', 'hybrid', 'lpg', 'other'];
  String _selectedFuel = 'petrol';

  static const _drivetrainOptions = ['fwd', 'rwd', 'awd', 'other'];
  String _selectedDrivetrain = 'fwd';

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _classCtrl.dispose();
    _price.dispose();
    _mileage.dispose();
    _year.dispose();
    _engineCc.dispose();
    _color.dispose();
    _condition.dispose();
    _techNotes.dispose();
    _vin.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remain = 10 - _photoPaths.length;
    if (remain <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 10 photos.')),
        );
      }
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final f in picked) {
        if (_photoPaths.length >= 10) break;
        _photoPaths.add(f.path);
      }
    });
  }

  void _removePhotoAt(int i) {
    setState(() => _photoPaths.removeAt(i));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    final mileage = int.tryParse(_mileage.text.trim().replaceAll(RegExp(r'\s'), ''));
    if (mileage == null || mileage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid mileage (km).')),
      );
      return;
    }

    final yearText = _year.text.trim();
    final modelYear = yearText.isEmpty ? 0 : int.tryParse(yearText);
    if (modelYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid model year or leave empty for unknown.')),
      );
      return;
    }
    if (modelYear != 0 && (modelYear < 1980 || modelYear > 2035)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model year must be 1980–2035, or 0 / empty if unknown.')),
      );
      return;
    }

    final engineCc = int.tryParse(_engineCc.text.trim().replaceAll(RegExp(r'\s'), '')) ?? 0;
    if (engineCc < 0 || engineCc > 20000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engine displacement (cc) must be between 0 and 20000.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await VehiclesApi.createListing(
        title: _title.text,
        city: _city.text,
        className: _selectedClass,
        pricePerDay: price,
        mileageKm: mileage,
        modelYear: modelYear,
        transmission: _selectedTransmission,
        fuelType: _selectedFuel,
        drivetrain: _selectedDrivetrain,
        engineCc: engineCc,
        exteriorColor: _color.text,
        conditionSummary: _condition.text,
        techNotes: _techNotes.text,
        vin: _vin.text,
      );
      if (!context.mounted) return;

      final vehicleId = (result['id'] as num).toInt();
      for (final path in _photoPaths) {
        try {
          await VehiclesApi.uploadVehiclePhoto(vehicleId: vehicleId, filePath: path);
        } catch (_) {
          // Non-fatal: listing exists; user can add more photos later.
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
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Up to 10 photos. First photo is the cover in the catalog.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photoPaths.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_photoPaths[i]),
                              width: 108,
                              height: 108,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => _photoAddTile(cs, isError: true),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                                onPressed: () => _removePhotoAt(i),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photoPaths.length < 10)
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: _photoAddTile(cs, isError: false),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Basics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

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

            Text(
              'Vehicle class',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classOptions
                  .map(
                    (c) => ChoiceChip(
                      label: Text(_classLabel(c)),
                      selected: _selectedClass == c,
                      onSelected: (_) => setState(() => _selectedClass = c),
                    ),
                  )
                  .toList(),
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

            const SizedBox(height: 28),

            Text(
              'Technical details',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Helps renters compare options.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mileage (km)',
                hintText: 'e.g. 45000',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim().replaceAll(RegExp(r'\s'), ''));
                if (n == null || n < 0) return 'Enter mileage in km';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Model year (optional)',
                hintText: 'Leave empty if unknown',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 14),

            _labeledChips(
              context,
              'Transmission',
              _transmissionOptions,
              _selectedTransmission,
              (v) => setState(() => _selectedTransmission = v),
              _transmissionLabel,
            ),
            const SizedBox(height: 14),
            _labeledChips(
              context,
              'Fuel',
              _fuelOptions,
              _selectedFuel,
              (v) => setState(() => _selectedFuel = v),
              _fuelLabel,
            ),
            const SizedBox(height: 14),
            _labeledChips(
              context,
              'Drivetrain',
              _drivetrainOptions,
              _selectedDrivetrain,
              (v) => setState(() => _selectedDrivetrain = v),
              _drivetrainLabel,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _engineCc,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Engine displacement (cc)',
                hintText: '0 if unknown or electric',
                prefixIcon: Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _color,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Exterior color',
                hintText: 'e.g. Pearl white',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _vin,
              textCapitalization: TextCapitalization.characters,
              maxLength: 17,
              decoration: const InputDecoration(
                labelText: 'VIN (optional)',
                hintText: 'Up to 17 letters and digits',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              validator: (v) {
                final s = (v ?? '').trim().toUpperCase();
                if (s.isEmpty) return null;
                if (s.length > 17) return 'Max 17 characters';
                if (!RegExp(r'^[A-Z0-9]+$').hasMatch(s)) return 'Letters and digits only';
                return null;
              },
            ),

            const SizedBox(height: 20),

            Text(
              'Condition & notes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _condition,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Condition & service history',
                hintText: 'Scratches, recent service, tires, interior wear…',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.fact_check_outlined),
                ),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 3) return 'Describe the condition (at least 3 characters)';
                if (s.length > 2000) return 'Too long (max 2000 characters)';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _techNotes,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Extra technical notes (optional)',
                hintText: 'Options, winter tires, charging cable, known quirks…',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.build_outlined),
                ),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length > 4000) return 'Too long (max 4000 characters)';
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

  Widget _labeledChips(
    BuildContext context,
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onSelect,
    String Function(String) label,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (c) => ChoiceChip(
                  label: Text(label(c)),
                  selected: selected == c,
                  onSelected: (_) => onSelect(c),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _photoAddTile(ColorScheme cs, {required bool isError}) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.broken_image_outlined : Icons.add_photo_alternate_outlined,
            size: 32,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            isError ? 'Error' : 'Add',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, fontSize: 12),
          ),
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

  String _transmissionLabel(String c) => switch (c) {
        'automatic' => 'Automatic',
        'manual' => 'Manual',
        'cvt' => 'CVT',
        'other' => 'Other',
        _ => c,
      };

  String _fuelLabel(String c) => switch (c) {
        'petrol' => 'Petrol',
        'diesel' => 'Diesel',
        'electric' => 'Electric',
        'hybrid' => 'Hybrid',
        'lpg' => 'LPG',
        'other' => 'Other',
        _ => c,
      };

  String _drivetrainLabel(String c) => switch (c) {
        'fwd' => 'FWD',
        'rwd' => 'RWD',
        'awd' => 'AWD',
        'other' => 'Other',
        _ => c,
      };
}
