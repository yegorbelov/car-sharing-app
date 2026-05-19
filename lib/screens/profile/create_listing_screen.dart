import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../models/vehicle.dart';
import '../../services/vehicles_api.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../../widgets/listing_suggestion_field.dart';
import 'listing_map_picker_screen.dart';

class _GalleryPhoto {
  const _GalleryPhoto.network(this.value) : isNetwork = true;
  const _GalleryPhoto.local(this.value) : isNetwork = false;

  final String value;
  final bool isNetwork;
}

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, this.vehicle});

  /// When set, the form opens in edit mode for this listing.
  final Vehicle? vehicle;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const _pageBg = Color(0xFFF4F6FA);

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _price = TextEditingController();
  final _mileage = TextEditingController();
  final _year = TextEditingController();
  final _engineCc = TextEditingController();
  final _color = TextEditingController();
  final _techNotes = TextEditingController();
  final _vin = TextEditingController();
  final _minDays = TextEditingController(text: '1');
  final _maxDays = TextEditingController(text: '14');
  final _seats = TextEditingController(text: '5');

  bool _submitting = false;
  bool _petsAllowed = false;

  static const _fuelReturnOptions = [
    'same_level',
    'full_tank',
    'quarter_tank',
  ];
  String _selectedFuelReturn = 'same_level';
  final List<_GalleryPhoto> _galleryPhotos = [];

  bool get _isEditing => widget.vehicle != null;
  int? get _editingId => widget.vehicle?.id;

  static const _classOptions = [
    'sedan',
    'suv',
    'economy',
    'comfort',
    'business',
  ];
  String _selectedClass = 'sedan';

  static const _transmissionOptions = ['automatic', 'manual', 'cvt', 'other'];
  String _selectedTransmission = 'automatic';

  static const _fuelOptions = [
    'petrol',
    'diesel',
    'electric',
    'hybrid',
    'lpg',
    'other',
  ];
  String _selectedFuel = 'petrol';

  static const _drivetrainOptions = ['fwd', 'rwd', 'awd', 'other'];
  String _selectedDrivetrain = 'fwd';

  static const _conditionOptions = [
    'like_new',
    'excellent',
    'good',
    'minor_scratches',
    'fair',
    'needs_attention',
  ];
  String _selectedCondition = 'good';

  List<String> _citySuggestions = ListingFormSuggestions.defaultCities;
  List<String> _titleSuggestions = ListingFormSuggestions.popularTitles;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) _prefillFromVehicle(v);
    _loadSuggestions();
  }

  void _prefillFromVehicle(Vehicle v) {
    _title.text = v.title;
    _city.text = v.city;
    _price.text = v.pricePerDay.toStringAsFixed(
      v.pricePerDay.truncateToDouble() == v.pricePerDay ? 0 : 2,
    );
    _mileage.text = v.mileageKm > 0 ? '${v.mileageKm}' : '';
    _year.text = v.modelYear > 0 ? '${v.modelYear}' : '';
    _engineCc.text = v.engineCc > 0 ? '${v.engineCc}' : '';
    _color.text = v.exteriorColor;
    _techNotes.text = v.techNotes;
    _vin.text = v.vin;
    _minDays.text = '${v.minRentalDays}';
    _maxDays.text = '${v.maxRentalDays}';
    _seats.text = '${v.seatCount}';
    _petsAllowed = v.petsAllowed;
    if (_fuelReturnOptions.contains(v.fuelReturnPolicy)) {
      _selectedFuelReturn = v.fuelReturnPolicy;
    }
    _latitude = v.latitude;
    _longitude = v.longitude;

    if (_classOptions.contains(v.className)) _selectedClass = v.className;
    if (_transmissionOptions.contains(v.transmission)) {
      _selectedTransmission = v.transmission;
    }
    if (_fuelOptions.contains(v.fuelType)) _selectedFuel = v.fuelType;
    if (_drivetrainOptions.contains(v.drivetrain)) {
      _selectedDrivetrain = v.drivetrain;
    }
    _selectedCondition = _conditionFromSummary(v.conditionSummary);

    _galleryPhotos.clear();
    for (final url in v.galleryUrls) {
      _galleryPhotos.add(_GalleryPhoto.network(url));
    }
  }

  String _conditionFromSummary(String summary) {
    for (final key in _conditionOptions) {
      if (_conditionSummaryFor(key) == summary) return key;
    }
    final lower = summary.toLowerCase();
    if (lower.contains('like new')) return 'like_new';
    if (lower.contains('excellent')) return 'excellent';
    if (lower.contains('minor scratch')) return 'minor_scratches';
    if (lower.contains('fair')) return 'fair';
    if (lower.contains('needs attention')) return 'needs_attention';
    return 'good';
  }

  Future<void> _loadSuggestions() async {
    try {
      final raw = await VehiclesApi.fetchRaw();
      if (!mounted) return;
      final vehicles = raw.map((e) => Vehicle.fromJson(e)).toList();
      setState(() {
        _citySuggestions = ListingFormSuggestions.citiesFromCatalog(
          vehicles.map((v) => v.city),
        );
        _titleSuggestions = ListingFormSuggestions.titlesFromCatalog(
          vehicles.map((v) => v.title),
        );
      });
    } catch (_) {
      // Keep built-in defaults.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _price.dispose();
    _mileage.dispose();
    _year.dispose();
    _engineCc.dispose();
    _color.dispose();
    _techNotes.dispose();
    _vin.dispose();
    _minDays.dispose();
    _maxDays.dispose();
    _seats.dispose();
    super.dispose();
  }

  ({int min, int max, int seats})? _parseRentalRules() {
    final min = int.tryParse(_minDays.text.trim());
    final max = int.tryParse(_maxDays.text.trim());
    final seats = int.tryParse(_seats.text.trim());
    if (min == null || min < 1 || min > 90) {
      context.showAppSnackBar('Min rental days must be between 1 and 90.');
      return null;
    }
    if (max == null || max < 1 || max > 90) {
      context.showAppSnackBar('Max rental days must be between 1 and 90.');
      return null;
    }
    if (min > max) {
      context.showAppSnackBar('Min days cannot be greater than max days.');
      return null;
    }
    if (seats == null || seats < 1 || seats > 12) {
      context.showAppSnackBar('Seat count must be between 1 and 12.');
      return null;
    }
    return (min: min, max: max, seats: seats);
  }

  Future<void> _pickPhotos() async {
    if (_galleryPhotos.length >= 10) {
      if (mounted) {
        context.showAppSnackBar('You can add up to 10 photos.');
      }
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final f in picked) {
        if (_galleryPhotos.length >= 10) break;
        _galleryPhotos.add(_GalleryPhoto.local(f.path));
      }
    });
  }

  void _removePhotoAt(int i) {
    setState(() => _galleryPhotos.removeAt(i));
  }

  Future<void> _openMapPicker() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ListingMapPickerScreen(
          city: _city.text,
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    final mileage = int.tryParse(
      _mileage.text.trim().replaceAll(RegExp(r'\s'), ''),
    );
    if (mileage == null || mileage < 0) {
      context.showAppSnackBar('Enter a valid mileage (km).');
      return;
    }

    final yearText = _year.text.trim();
    final modelYear = yearText.isEmpty ? 0 : int.tryParse(yearText);
    if (modelYear == null) {
      context.showAppSnackBar(
        'Enter a valid model year or leave empty for unknown.',
      );
      return;
    }
    if (modelYear != 0 && (modelYear < 1980 || modelYear > 2035)) {
      context.showAppSnackBar(
        'Model year must be 1980–2035, or 0 / empty if unknown.',
      );
      return;
    }

    final engineCc =
        int.tryParse(_engineCc.text.trim().replaceAll(RegExp(r'\s'), '')) ?? 0;
    if (engineCc < 0 || engineCc > 20000) {
      context.showAppSnackBar(
        'Engine displacement (cc) must be between 0 and 20000.',
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      context.showAppSnackBar('Open the map and set pickup location.');
      return;
    }

    final rentalRules = _parseRentalRules();
    if (rentalRules == null) return;

    setState(() => _submitting = true);
    try {
      final summary = _conditionSummaryText();
      final remoteUrls = _galleryPhotos
          .where((p) => p.isNetwork)
          .map((p) => p.value)
          .toList();
      final localPaths = _galleryPhotos
          .where((p) => !p.isNetwork)
          .map((p) => p.value)
          .toList();

      late final int vehicleId;
      if (_isEditing) {
        vehicleId = _editingId!;
        await VehiclesApi.updateListing(
          vehicleId: vehicleId,
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
          conditionSummary: summary,
          techNotes: _techNotes.text,
          vin: _vin.text,
          latitude: _latitude!,
          longitude: _longitude!,
          minRentalDays: rentalRules.min,
          maxRentalDays: rentalRules.max,
          seatCount: rentalRules.seats,
          petsAllowed: _petsAllowed,
          fuelReturnPolicy: _selectedFuelReturn,
          photoUrls: remoteUrls,
        );
      } else {
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
          conditionSummary: summary,
          techNotes: _techNotes.text,
          vin: _vin.text,
          latitude: _latitude!,
          longitude: _longitude!,
          minRentalDays: rentalRules.min,
          maxRentalDays: rentalRules.max,
          seatCount: rentalRules.seats,
          petsAllowed: _petsAllowed,
          fuelReturnPolicy: _selectedFuelReturn,
        );
        vehicleId = (result['id'] as num).toInt();
      }

      if (!context.mounted) return;

      var failedPhotos = 0;
      for (final path in localPaths) {
        try {
          await VehiclesApi.uploadVehiclePhoto(
            vehicleId: vehicleId,
            filePath: path,
          );
        } catch (_) {
          failedPhotos++;
        }
      }

      if (!context.mounted) return;
      if (failedPhotos > 0) {
        final action = _isEditing ? 'Saved' : 'Submitted for review';
        context.showAppSnackBar(
          failedPhotos == localPaths.length
              ? '$action, but photos could not be uploaded.'
              : '$action, but $failedPhotos photo(s) failed to upload.',
        );
      } else if (_isEditing) {
        final v = widget.vehicle!;
        final msg = v.isPublished || v.isRejected
            ? 'Changes saved. Listing is under review again.'
            : 'Listing updated.';
        context.showAppSnackBar(msg, kind: AppSnackBarKind.success);
      }

      if (_isEditing) {
        Navigator.of(context).pop(true);
        return;
      }

      if (failedPhotos == 0) {
        await IllustratedEmptyState.showListingSubmittedForReview(context);
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      context.showAppSnackBar('$e');
    } finally {
      if (context.mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit listing' : 'New listing'),
        backgroundColor: _pageBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  Text(
                    _isEditing
                        ? 'Update your listing details. Published listings go back to review after edits.'
                        : 'Add your car to the catalog so renters can find and book it.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ListingFormSection(
                    icon: Icons.photo_library_outlined,
                    iconColor: const Color(0xFF1565C0),
                    iconBg: const Color(0xFFE3F2FD),
                    title: 'Photos',
                    subtitle: 'First photo is the cover · up to 10',
                    child: _PhotosBlock(
                      photos: _galleryPhotos,
                      onAdd: _pickPhotos,
                      onRemove: _removePhotoAt,
                    ),
                  ),
                  _ListingFormSection(
                    icon: Icons.directions_car_outlined,
                    iconColor: cs.primary,
                    iconBg: cs.primaryContainer,
                    title: 'Basics',
                    child: Column(
                      children: [
                        ListingSuggestionField(
                          controller: _title,
                          suggestions: _titleSuggestions,
                          textCapitalization: TextCapitalization.words,
                          labelText: 'Make & model',
                          hintText: 'Toyota Camry 2022',
                          icon: Icons.directions_car_outlined,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        ListingSuggestionField(
                          controller: _city,
                          suggestions: _citySuggestions,
                          textCapitalization: TextCapitalization.words,
                          labelText: 'City',
                          hintText: 'Moscow',
                          icon: Icons.location_on_outlined,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                          suffixIcon: IconButton(
                            tooltip: 'Pick location on map',
                            onPressed: _openMapPicker,
                            icon: Icon(
                              _latitude != null
                                  ? Icons.map_rounded
                                  : Icons.map_outlined,
                              color: _latitude != null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (_latitude != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pickup: ${_latitude!.toStringAsFixed(5)}, '
                            '${_longitude!.toStringAsFixed(5)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _OptionChipGroup(
                          label: 'Vehicle class',
                          options: _classOptions,
                          selected: _selectedClass,
                          labelFor: _classLabel,
                          onSelected: (v) => setState(() => _selectedClass = v),
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Price per day (USD)',
                            hintText: '75',
                            icon: Icons.payments_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final p = double.tryParse(
                              v.trim().replaceAll(',', '.'),
                            );
                            if (p == null || p <= 0) return 'Enter a valid price';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  _ListingFormSection(
                    icon: Icons.event_available_outlined,
                    iconColor: const Color(0xFF1565C0),
                    iconBg: const Color(0xFFE3F2FD),
                    title: 'Rental rules',
                    subtitle: 'Trip length, seats, fuel, and pets',
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minDays,
                                keyboardType: TextInputType.number,
                                decoration: AppInputs.decoration(
                                  context,
                                  labelText: 'Min days',
                                  hintText: '1',
                                  icon: Icons.today_outlined,
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n < 1 || n > 90) {
                                    return '1–90';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _maxDays,
                                keyboardType: TextInputType.number,
                                decoration: AppInputs.decoration(
                                  context,
                                  labelText: 'Max days',
                                  hintText: '14',
                                  icon: Icons.date_range_outlined,
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n < 1 || n > 90) {
                                    return '1–90';
                                  }
                                  final min = int.tryParse(_minDays.text.trim());
                                  if (min != null && n < min) {
                                    return '≥ min';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _seats,
                          keyboardType: TextInputType.number,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Seats',
                            hintText: '5',
                            icon: Icons.event_seat_outlined,
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1 || n > 12) return '1–12';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _OptionChipGroup(
                          label: 'Fuel at return',
                          options: _fuelReturnOptions,
                          selected: _selectedFuelReturn,
                          labelFor: _fuelReturnLabel,
                          onSelected: (v) =>
                              setState(() => _selectedFuelReturn = v),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pets allowed'),
                          subtitle: const Text(
                            'Renters may bring pets if you allow it',
                          ),
                          value: _petsAllowed,
                          onChanged: (v) => setState(() => _petsAllowed = v),
                        ),
                      ],
                    ),
                  ),
                  _ListingFormSection(
                    icon: Icons.build_circle_outlined,
                    iconColor: const Color(0xFFE65100),
                    iconBg: const Color(0xFFFFF3E0),
                    title: 'Technical details',
                    subtitle: 'Helps renters compare options',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _mileage,
                          keyboardType: TextInputType.number,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Mileage (km)',
                            hintText: '45000',
                            icon: Icons.speed_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(
                              v.trim().replaceAll(RegExp(r'\s'), ''),
                            );
                            if (n == null || n < 0) return 'Enter mileage in km';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _year,
                          keyboardType: TextInputType.number,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Model year (optional)',
                            hintText: 'Leave empty if unknown',
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _OptionChipGroup(
                          label: 'Transmission',
                          options: _transmissionOptions,
                          selected: _selectedTransmission,
                          labelFor: _transmissionLabel,
                          onSelected: (v) =>
                              setState(() => _selectedTransmission = v),
                        ),
                        const SizedBox(height: 14),
                        _OptionChipGroup(
                          label: 'Fuel',
                          options: _fuelOptions,
                          selected: _selectedFuel,
                          labelFor: _fuelLabel,
                          onSelected: (v) => setState(() => _selectedFuel = v),
                        ),
                        const SizedBox(height: 14),
                        _OptionChipGroup(
                          label: 'Drivetrain',
                          options: _drivetrainOptions,
                          selected: _selectedDrivetrain,
                          labelFor: _drivetrainLabel,
                          onSelected: (v) =>
                              setState(() => _selectedDrivetrain = v),
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _engineCc,
                          keyboardType: TextInputType.number,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Engine (cc)',
                            hintText: '0 if unknown or electric',
                            icon: Icons.settings_outlined,
                          ),
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _color,
                          textCapitalization: TextCapitalization.words,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Exterior color',
                            hintText: 'Pearl white',
                            icon: Icons.palette_outlined,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _vin,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 17,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'VIN (optional)',
                            hintText: '17 letters and digits',
                            icon: Icons.tag_outlined,
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim().toUpperCase();
                            if (s.isEmpty) return null;
                            if (s.length > 17) return 'Max 17 characters';
                            if (!RegExp(r'^[A-Z0-9]+$').hasMatch(s)) {
                              return 'Letters and digits only';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  _ListingFormSection(
                    icon: Icons.fact_check_outlined,
                    iconColor: const Color(0xFF2E7D32),
                    iconBg: const Color(0xFFE8F5E9),
                    title: 'Condition & notes',
                    subtitle: 'Pick the closest match — add details below if needed',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OptionChipGroup(
                          label: 'Vehicle condition',
                          options: _conditionOptions,
                          selected: _selectedCondition,
                          labelFor: _conditionLabel,
                          onSelected: (v) =>
                              setState(() => _selectedCondition = v),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _conditionDescription(_selectedCondition),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: AppInputs.fieldGap),
                        TextFormField(
                          controller: _techNotes,
                          minLines: 2,
                          maxLines: 8,
                          decoration: AppInputs.decoration(
                            context,
                            labelText: 'Service history & extras (optional)',
                            hintText:
                                'Recent service, tires, options, known quirks…',
                            alignLabelWithHint: true,
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length > 4000) return 'Max 4000 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _PublishBar(
              submitting: _submitting,
              bottomInset: bottom,
              label: _isEditing ? 'Save changes' : 'Submit for review',
              onPublish: _submit,
            ),
          ],
        ),
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

  String _fuelReturnLabel(String c) => switch (c) {
    'full_tank' => 'Full tank',
    'quarter_tank' => 'At least ¼ tank',
    'same_level' || _ => 'Same as pickup',
  };

  String _drivetrainLabel(String c) => switch (c) {
    'fwd' => 'FWD',
    'rwd' => 'RWD',
    'awd' => 'AWD',
    'other' => 'Other',
    _ => c,
  };

  String _conditionLabel(String c) => switch (c) {
    'like_new' => 'Like new',
    'excellent' => 'Excellent',
    'good' => 'Good',
    'minor_scratches' => 'Minor scratches',
    'fair' => 'Fair wear',
    'needs_attention' => 'Needs attention',
    _ => c,
  };

  String _conditionDescription(String c) => switch (c) {
    'like_new' => 'Looks and drives like a new car — no visible defects.',
    'excellent' =>
        'Very clean inside and out, fully maintained, no notable flaws.',
    'good' => 'Normal wear for age and mileage, no major cosmetic issues.',
    'minor_scratches' =>
        'Small scratches, scuffs, or dings — nothing affecting safety.',
    'fair' => 'Visible wear or cosmetic damage, still safe and roadworthy.',
    'needs_attention' =>
        'Known issues renters should know about — describe them in the notes.',
    _ => '',
  };

  String _conditionSummaryText() => _conditionSummaryFor(_selectedCondition);

  String _conditionSummaryFor(String c) => switch (c) {
    'like_new' => 'Like new — no visible wear or defects.',
    'excellent' => 'Excellent condition, well maintained inside and out.',
    'good' => 'Good condition with light wear appropriate for mileage.',
    'minor_scratches' =>
        'Minor scratches or cosmetic marks; mechanically sound.',
    'fair' => 'Fair condition with visible wear; drives reliably.',
    'needs_attention' =>
        'Needs attention — see notes for known issues and history.',
    _ => _conditionDescription(c),
  };
}

class _ListingFormSection extends StatelessWidget {
  const _ListingFormSection({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotosBlock extends StatelessWidget {
  const _PhotosBlock({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_GalleryPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (photos.isEmpty) {
      return Material(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 40,
                  color: cs.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add photos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to choose from gallery',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${photos.length} / 10',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: photos.length < 10 ? onAdd : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add more'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + (photos.length < 10 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == photos.length) {
                return _PhotoAddTile(onTap: onAdd);
              }
              final isCover = i == 0;
              final photo = photos[i];
              return _PhotoThumb(
                photo: photo,
                isCover: isCover,
                onRemove: () => onRemove(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.isCover,
    required this.onRemove,
  });

  final _GalleryPhoto photo;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final w = isCover ? 168.0 : 108.0;
    final image = photo.isNetwork
        ? Image.network(
            fullImageUrl(photo.value),
            width: w,
            height: 124,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _broken(w),
          )
        : Image.file(
            File(photo.value),
            width: w,
            height: 124,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _broken(w),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: image,
        ),
        if (isCover)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Cover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _broken(double w) {
    return Container(
      width: w,
      height: 124,
      color: const Color(0xFFE8ECF4),
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _PhotoAddTile extends StatelessWidget {
  const _PhotoAddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 108,
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 28, color: cs.primary),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChipGroup extends StatelessWidget {
  const _OptionChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String selected;
  final String Function(String) labelFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                _ListingOptionChip(
                  label: labelFor(o),
                  selected: selected == o,
                  onTap: () => onSelected(o),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListingOptionChip extends StatelessWidget {
  const _ListingOptionChip({
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

    final bg = selected ? cs.primary : const Color(0xFFF4F6FA);
    final border = selected ? cs.primary : const Color(0xFFE2E6EF);

    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      constrainedAxis: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Material(
        color: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.submitting,
    required this.bottomInset,
    required this.label,
    required this.onPublish,
  });

  final bool submitting;
  final double bottomInset;
  final String label;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8ECF4))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: FilledButton(
          onPressed: submitting ? null : onPublish,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF111111).withValues(alpha: 0.4),
          ),
          child: submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
