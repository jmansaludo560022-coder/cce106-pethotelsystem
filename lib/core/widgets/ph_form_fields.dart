import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/ph_locations.dart';
import '../utils/ph_phone.dart';

/// PH mobile number field (spec §10.1): fixed 🇵🇭 +63 prefix, the user types
/// the 10 digits starting with 9, auto-formatted as `9XX XXX XXXX`.
/// Use [PhPhone.normalize] on `'+63${controller.text}'` to get the E.164 value.
class PhPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  const PhPhoneField({super.key, required this.controller, this.label = 'Mobile number', this.textInputAction});

  /// The stored value (`+639171234567`) for what is typed, or null if invalid.
  static String? e164Of(TextEditingController c) => PhPhone.normalize('+63${c.text}');

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      inputFormatters: [PhLocalPhoneFormatter()],
      autovalidateMode: AutovalidateMode.onUnfocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: '912 345 6789',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🇵🇭'),
            SizedBox(width: 6),
            Text('+63', style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: PhPhone.validateLocal,
    );
  }
}

/// A form field that opens a searchable bottom-sheet list (spec §8: dropdowns
/// such as region use the same box and a searchable sheet, not a raw menu).
class SearchablePickerField extends FormField<PhPlace> {
  SearchablePickerField({
    super.key,
    required String label,
    required List<PhPlace> options,
    required PhPlace? value,
    required ValueChanged<PhPlace> onSelected,
    super.enabled,
    String? disabledHint,
    String requiredMessage = 'Please choose an option.',
  }) : super(
          initialValue: value,
          validator: (v) => v == null ? requiredMessage : null,
          builder: (state) {
            final context = state.context;
            final current = state.value;
            Future<void> open() async {
              final picked = await showModalBottomSheet<PhPlace>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _SearchSheet(title: label, options: options),
              );
              if (picked != null) {
                state.didChange(picked);
                onSelected(picked);
              }
            }

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: state.widget.enabled ? open : null,
              child: InputDecorator(
                isEmpty: current == null,
                decoration: InputDecoration(
                  labelText: label,
                  enabled: state.widget.enabled,
                  errorText: state.errorText,
                  hintText: state.widget.enabled ? null : disabledHint,
                  suffixIcon: const Icon(Icons.expand_more_rounded),
                ),
                child: Text(current?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.inputText),
              ),
            );
          },
        );
}

class _SearchSheet extends StatefulWidget {
  final String title;
  final List<PhPlace> options;
  const _SearchSheet({required this.title, required this.options});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = q.isEmpty ? widget.options : widget.options.where((o) => o.name.toLowerCase().contains(q)).toList();
    final height = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: InputDecoration(hintText: 'Search ${widget.title.toLowerCase()}', prefixIcon: const Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No matches'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(title: Text(list[i].name), onTap: () => Navigator.pop(context, list[i])),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Philippine address block (spec §10.2, owner decisions): Region → Province
/// (hidden for NCR) → City/Municipality as required searchable dropdowns that
/// clear their children when changed, then Barangay and Street typed in.
class PhAddressFields extends StatefulWidget {
  final PhAddress initial;
  final ValueChanged<PhAddress> onChanged;

  /// Shown when an older record only has the single-line address.
  final String? legacyAddress;

  const PhAddressFields({super.key, required this.initial, required this.onChanged, this.legacyAddress});

  @override
  State<PhAddressFields> createState() => _PhAddressFieldsState();
}

class _PhAddressFieldsState extends State<PhAddressFields> {
  late PhAddress _a = widget.initial;
  late final _barangay = TextEditingController(text: widget.initial.barangay);
  late final _street = TextEditingController(text: widget.initial.street);
  late final _houseUnit = TextEditingController(text: widget.initial.houseUnit);
  late final Future<PhLocations> _data = PhLocations.load();
  int _version = 0; // forces child pickers to reset when a parent changes

  @override
  void dispose() {
    _barangay.dispose();
    _street.dispose();
    _houseUnit.dispose();
    super.dispose();
  }

  void _set(PhAddress a) {
    setState(() => _a = a);
    widget.onChanged(a);
  }

  /// A typed barangay belongs to the chosen city: when the region, province
  /// or city changes, it is cleared so it cannot conflict with the new place.
  PhAddress _clearBarangay(PhAddress a) {
    if (_barangay.text.isNotEmpty) _barangay.clear();
    return a.copyWith(barangay: '');
  }

  PhPlace? _find(List<PhPlace> list, String code) {
    for (final p in list) {
      if (p.code == code) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return FutureBuilder<PhLocations>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Text('Could not load the address list: ${snap.error}', style: const TextStyle(color: AppColors.errorText));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
        final loc = snap.data!;
        final region = _find(loc.regions, _a.regionCode);
        final hasProvinces = region != null && loc.regionHasProvinces(region.code);
        final provinces = region == null ? <PhPlace>[] : loc.provincesOf(region.code);
        final province = _find(provinces, _a.provinceCode);
        final cities = region == null ? <PhPlace>[] : loc.citiesOf(region.code, provinceCode: hasProvinces ? province?.code : null);
        final city = _find(cities, _a.cityCode);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.legacyAddress != null && widget.legacyAddress!.isNotEmpty && !_a.isComplete) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.infoText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Address on file: ${widget.legacyAddress}\nPlease re-enter it using the fields below.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.infoText),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          SearchablePickerField(
            key: const ValueKey('region'),
            label: 'Region',
            options: loc.regions,
            value: region,
            requiredMessage: 'Please choose your region.',
            onSelected: (p) {
              _version++;
              if (p.code == _a.regionCode) return;
              _set(_clearBarangay(PhAddress(regionCode: p.code, regionName: p.name, street: _a.street, houseUnit: _a.houseUnit)));
            },
          ),
          if (region == null || hasProvinces) ...[
            gap,
            SearchablePickerField(
              key: ValueKey('province$_version'),
              label: 'Province',
              options: provinces,
              value: province,
              enabled: region != null,
              disabledHint: 'Choose a region first',
              requiredMessage: 'Please choose your province.',
              onSelected: (p) {
                if (p.code == _a.provinceCode) return;
                _version++;
                _set(_clearBarangay(_a.copyWith(provinceCode: p.code, provinceName: p.name, cityCode: '', cityName: '')));
              },
            ),
          ],
          gap,
          SearchablePickerField(
            key: ValueKey('city$_version'),
            label: 'City / Municipality',
            options: cities,
            value: city,
            enabled: region != null && (!hasProvinces || province != null),
            disabledHint: region == null ? 'Choose a region first' : 'Choose a province first',
            requiredMessage: 'Please choose your city or municipality.',
            onSelected: (p) {
              if (p.code == _a.cityCode) return;
              _set(_clearBarangay(_a.copyWith(cityCode: p.code, cityName: p.name)));
            },
          ),
          gap,
          // Typed (owner decision 2026-10-03: no barangay list). Enabled once
          // a city is chosen, and cleared whenever the city changes.
          TextFormField(
            key: const ValueKey('barangay'),
            controller: _barangay,
            enabled: city != null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Barangay',
              hintText: 'e.g. Matina Crossing',
              helperText: city == null ? 'Choose a city or municipality first' : null,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Barangay is required.' : null,
            onChanged: (v) => _set(_a.copyWith(barangay: v)),
          ),
          gap,
          // Decision D2: street and house number are separate fields.
          TextFormField(
            key: const ValueKey('street'),
            controller: _street,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Street', hintText: 'e.g. Acacia St., Purok 3, or subdivision'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Street is required.' : null,
            onChanged: (v) => _set(_a.copyWith(street: v)),
          ),
          gap,
          TextFormField(
            key: const ValueKey('houseUnit'),
            controller: _houseUnit,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'House / building / unit no. (optional)', hintText: 'e.g. Blk 2 Lot 5, Unit 3B'),
            onChanged: (v) => _set(_a.copyWith(houseUnit: v)),
          ),
        ]);
      },
    );
  }
}
