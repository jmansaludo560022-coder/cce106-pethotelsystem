import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/upload_rules.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/pet_model.dart';
import '../../services/pet_service.dart';
import '../../core/constants/app_spacing.dart';

/// C-03 Pet registration / edit form (PET-002 … PET-006).
///
/// Fixes ISS-18/19/20: the pet is really saved to Firestore, the vaccination
/// record is uploaded to Firebase Storage, the selected file can be previewed
/// and removed, instructions are shown, and existing pets can be edited.
class PetFormScreen extends StatefulWidget {
  final String cusID;
  final PetModel? existing;

  /// Customers must attach a vaccination record (the form marks it with *).
  /// Walk-in pets registered by the admin may skip it (Q-05).
  final bool requireVaccination;

  const PetFormScreen({super.key, required this.cusID, this.existing, this.requireVaccination = true});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  static const _breeds = {
    'Dog': ['Aspin', 'Golden Retriever', 'Shiba Inu', 'Poodle', 'Miniature Pinscher', 'Shih Tzu', 'Labrador Retriever', 'Other'],
    'Cat': ['Puspin', 'Persian', 'Siamese', 'Maine Coon', 'British Shorthair', 'Other'],
  };
  static const _sizes = ['Small (S)', 'Medium (M)', 'Large (L)', 'Giant (XL)'];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.petName ?? '');
  late final _otherBreed = TextEditingController();
  late String _type = widget.existing?.petType ?? 'Dog';
  late String _breed;
  late String _gender = widget.existing?.gender ?? 'Male';
  late String _size = _sizes.contains(widget.existing?.weightSize) ? widget.existing!.weightSize : 'Medium (M)';
  late DateTime? _birthdate = widget.existing?.birthdate;

  /// New vaccination record (image or PDF, decision D5), already checked.
  UploadData? _vaccination;
  late String _existingVaccination = widget.existing?.vaccinationFile ?? '';
  bool _previewOpen = true;

  XFile? _photo;
  Uint8List? _photoBytes;

  bool _removeExistingPhoto = false;

  bool _saving = false;
  String? _saveError;

  /// Created once, so tapping Retry after a failure overwrites the same pet
  /// document instead of creating a duplicate (spec §11.1 / TC-07).
  late final String _draftId = PetService().newPetId();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (!_breeds.containsKey(_type)) _type = 'Dog';
    final existingBreed = widget.existing?.breed ?? '';
    if (existingBreed.isEmpty) {
      _breed = _breeds[_type]!.first;
    } else if (_breeds[_type]!.contains(existingBreed)) {
      _breed = existingBreed;
    } else {
      _breed = 'Other';
      _otherBreed.text = existingBreed;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _otherBreed.dispose();
    super.dispose();
  }

  /// Spec §11.2: the pet photo goes through the shared PhotoSourceSheet
  /// (Take photo / Choose from gallery / Remove).
  Future<void> _choosePhoto() async {
    final hasCurrent = _photoBytes != null || (!_removeExistingPhoto && (widget.existing?.petPhoto ?? '').isNotEmpty);
    final r = await showPhotoSourceSheet(context, title: 'Pet photo', allowRemove: hasCurrent);
    if (r == null || !mounted) return;
    setState(() {
      _saveError = null;
      _photo = r.photo?.file;
      _photoBytes = r.photo?.bytes;
      if (r.removed) _removeExistingPhoto = true;
    });
  }

  /// Decision D5: Take photo / Choose from gallery / Upload file (PDF or
  /// image). Type and size are checked before the file is accepted.
  Future<void> _chooseVaccination() async {
    final hasCurrent = _vaccination != null || _existingVaccination.isNotEmpty;
    final r = await showDocumentSourceSheet(context, title: 'Vaccination record', allowRemove: hasCurrent);
    if (r == null || !mounted) return;
    setState(() {
      _saveError = null;
      if (r.removed) {
        _vaccination = null;
        _existingVaccination = '';
      } else {
        _vaccination = r.file;
        _previewOpen = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final hasVaccination = _vaccination != null || _existingVaccination.isNotEmpty;
    if (widget.requireVaccination && !hasVaccination) {
      showError(context, 'Please attach a vaccination record (for example, the anti-rabies certificate).');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final breed = _breed == 'Other' ? _otherBreed.text.trim() : _breed;
      final pet = PetModel(
        petID: widget.existing?.petID ?? '',
        cusID: widget.cusID,
        petName: _name.text.trim(),
        petPhoto: _removeExistingPhoto ? '' : (widget.existing?.petPhoto ?? ''),
        petType: _type,
        breed: breed,
        gender: _gender,
        birthdate: _birthdate,
        weightSize: _size,
        vaccinationFile: _existingVaccination,
        createdAt: widget.existing?.createdAt,
      );
      await PetService().savePet(pet, vaccinationFile: _vaccination, photo: _photo, newId: _draftId);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, _editing ? '${pet.petName}\'s profile was updated.' : '${pet.petName} was registered.');
    } catch (e) {
      // Spec §11.1: show a clear message and keep the form filled for Retry.
      if (mounted) setState(() => _saveError = friendlyError(e));
    } finally {
      // The loader always stops (the success path has already left the screen).
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit pet profile' : 'Register a pet')),
      body: MaxWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
            Center(child: _photoPicker()),
            const SizedBox(height: AppSpacing.xxl),
            // Spec §9.4: fields grouped into titled sections.
            FormSection(
              title: 'Basic info',
              description: 'How the hotel will know your pet.',
              icon: Icons.pets_rounded,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Pet name'),
                  validator: (v) => Validators.required(v, 'Pet name'),
                ),
                DropdownButtonFormField<String>(
                  style: AppTextStyles.inputText,
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Pet type'),
                  items: _breeds.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() {
                    _type = v ?? _type;
                    _breed = _breeds[_type]!.first;
                  }),
                ),
                DropdownButtonFormField<String>(
                  style: AppTextStyles.inputText,
                  isExpanded: true,
                  key: ValueKey(_type),
                  initialValue: _breed,
                  decoration: const InputDecoration(labelText: 'Breed'),
                  items: _breeds[_type]!.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setState(() => _breed = v ?? _breed),
                ),
                if (_breed == 'Other')
                  TextFormField(
                    controller: _otherBreed,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Breed name'),
                    validator: (v) => Validators.required(v, 'Breed'),
                  ),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      style: AppTextStyles.inputText,
                      isExpanded: true,
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      style: AppTextStyles.inputText,
                      isExpanded: true,
                      initialValue: _size,
                                            decoration: const InputDecoration(labelText: 'Size'),
                      items: _sizes.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _size = v ?? _size),
                    ),
                  ),
                ]),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 30),
                      lastDate: now,
                      initialDate: _birthdate ?? DateTime(now.year - 1, now.month, now.day),
                      helpText: 'Pet birthdate',
                    );
                    if (d != null) setState(() => _birthdate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthdate (optional)',
                      suffixIcon: _birthdate == null
                          ? const Icon(Icons.cake_outlined)
                          : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _birthdate = null)),
                    ),
                    child: Text(_birthdate == null ? 'Not set' : Fmt.date(_birthdate!), style: AppTextStyles.inputText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            FormSection(
              title: widget.requireVaccination ? 'Vaccination record' : 'Vaccination record (optional)',
              description: 'Needed before your pet can stay with us.',
              icon: Icons.vaccines_rounded,
              children: [
                const TintedCard(
                  tintColor: AppColors.infoBg,
                  child: Text(
                    'Accepted: your pet\'s anti-rabies certificate or vaccination card (e.g. 5-in-1 / 4-in-1), '
                    'as a clear photo or a PDF. Make sure the pet\'s name and the vaccination dates are readable. Up to 5 MB.',
                    style: AppTextStyles.infoBanner,
                  ),
                ),
                _vaccinationBox(),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_saveError != null) ...[
              TintedCard(
                tintColor: AppColors.errorBg,
                borderColor: AppColors.errorBorder,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.errorText),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(_saveError!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorText))),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            PrimaryButton(
              label: _saving ? 'Saving…' : (_saveError != null ? 'Retry' : (_editing ? 'Save changes' : 'Save pet profile')),
              icon: _saveError != null && !_saving ? Icons.refresh_rounded : null,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ]),
        ),
      ),
    );
  }

  /// Spec §9.4: large circular avatar with a dashed mustard outline.
  Widget _photoPicker() {
    final existing = widget.existing?.petPhoto ?? '';
    const size = 120.0;
    Widget img;
    if (_photoBytes != null) {
      img = ClipOval(child: Image.memory(_photoBytes!, width: size, height: size, fit: BoxFit.cover));
    } else if (existing.isNotEmpty && !_removeExistingPhoto) {
      img = ClipOval(child: AppImage(url: existing, width: size, height: size, radius: size / 2));
    } else {
      img = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: AppColors.mustardSoft, shape: BoxShape.circle),
        child: const Icon(Icons.pets_rounded, size: 48, color: AppColors.ink),
      );
    }
    return Column(children: [
      Semantics(
        button: true,
        label: 'Pet photo. Tap to add or change',
        child: GestureDetector(
          onTap: _saving ? null : _choosePhoto,
          child: Stack(children: [
            CustomPaint(
              foregroundPainter: const _DashedCirclePainter(),
              child: Padding(padding: const EdgeInsets.all(AppSpacing.xs + 2), child: img),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Add pet photo',
                style: IconButton.styleFrom(backgroundColor: AppColors.ink),
                onPressed: _saving ? null : _choosePhoto,
                icon: const Icon(Icons.photo_camera_rounded, size: 18, color: AppColors.onInk),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.xs + 2),
      Text('Pet photo (optional)', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
    ]);
  }

  Widget _vaccinationBox() {
    if (_vaccination == null && _existingVaccination.isEmpty) {
      return AppCard(
        child: Column(children: [
          const Icon(Icons.upload_file_rounded, size: 38, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            cameraSupported ? 'Take a photo, choose one from your gallery, or upload a PDF' : 'Choose a photo or upload a PDF',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          InkButton(label: 'Add vaccination record', icon: Icons.add_rounded, onPressed: _saving ? null : _chooseVaccination),
        ]),
      );
    }
    return VaccinationFileTile(
      newFile: _vaccination,
      existingUrl: _existingVaccination,
      previewOpen: _previewOpen,
      enabled: !_saving,
      onTogglePreview: () => setState(() => _previewOpen = !_previewOpen),
      onRemove: () => setState(() {
        _vaccination = null;
        _existingVaccination = '';
      }),
      onReplace: _chooseVaccination,
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mustard
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    const dashes = 28;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1.5), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
