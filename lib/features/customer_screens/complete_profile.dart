import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/ph_locations.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/ph_form_fields.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';

/// Shown after the first Google sign-in (or any login that has no profile
/// yet): collects what the hotel needs — name, PH mobile number and home
/// address — and creates the customer profile. The email comes from the
/// login and is not typed again.
class CompleteProfileScreen extends StatefulWidget {
  /// For tests; defaults to the signed-in Firebase user.
  final String? email;
  final String? displayName;
  final VoidCallback? onSignOut;
  const CompleteProfileScreen({super.key, this.email, this.displayName, this.onSignOut});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final String _email = widget.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
  late final List<String> _names = _splitName(widget.displayName ?? FirebaseAuth.instance.currentUser?.displayName ?? '');
  late final _first = TextEditingController(text: _names[0]);
  final _middle = TextEditingController();
  late final _last = TextEditingController(text: _names[1]);
  final _phone = TextEditingController();
  PhAddress _address = PhAddress.empty;
  bool _saving = false;

  /// "Maria Clara Santos" → ["Maria Clara", "Santos"].
  static List<String> _splitName(String full) {
    final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return ['', ''];
    if (parts.length == 1) return [parts.first, ''];
    return [parts.sublist(0, parts.length - 1).join(' '), parts.last];
  }

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().completeProfileForCurrentUser(
        username: _email.split('@').first,
        firstName: _first.text,
        middleName: _middle.text,
        lastName: _last.text,
        phone: PhPhoneField.e164Of(_phone) ?? '',
        address: _address,
      );
      // The session listens to the new profile and opens the customer area.
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: _saving ? null : (widget.onSignOut ?? AuthService().signOut), child: const Text('Sign out')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: MaxWidth(
          maxWidth: 440,
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl), children: [
              const Center(child: Mascot(pose: MascotPose.wave, size: 96)),
              const SizedBox(height: AppSpacing.md),
              const Text('Complete your profile', style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Just a few details so the hotel can contact you about your bookings.',
                style: AppTextStyles.bodyMediumRole.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ReadOnlyItem(label: 'Signed in as', value: _email.isEmpty ? '—' : _email, icon: Icons.mail_outline_rounded),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _first,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: (v) => Validators.required(v, 'First name'),
              ),
              gap,
              TextFormField(
                controller: _middle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Middle name (optional)'),
              ),
              gap,
              TextFormField(
                controller: _last,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: (v) => Validators.required(v, 'Last name'),
              ),
              gap,
              PhPhoneField(controller: _phone),
              const SizedBox(height: AppSpacing.xl),
              const Text('Home address', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              PhAddressFields(initial: _address, onChanged: (a) => _address = a),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Save and continue', isLoading: _saving, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }
}
