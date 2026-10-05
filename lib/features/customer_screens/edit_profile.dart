import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/ph_phone.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/ph_form_fields.dart';
import '../../core/widgets/widgets.dart';
import '../../models/customer_model.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../services/customer_service.dart';

/// C-13 Account (owner request 2026-10-03, organised like familiar account
/// settings): one compact **Personal Information** list — full name, mobile
/// number, email, home address and Change Password. Each row opens a small
/// editor sheet, so the screen stays short; the address is shown as one
/// readable line while the saved data stays structured (region, province,
/// city, barangay, street, house/unit).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final c = session.customer;
    if (c == null) return const Scaffold(body: LoadingState());
    final username = session.user?.username ?? '';
    final auth = AuthService();
    final a11y = context.watch<AccessibilityProvider>();
    final address = c.phAddress.isComplete ? c.phAddress.formatted : c.address.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidth(
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl), children: [
            const PageHeader(title: 'Account', padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md)),
            _ProfileHeader(customer: c, username: username),
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(title: 'Personal information', rows: [
              SettingsRow(icon: Icons.badge_outlined, label: 'Full name', value: c.fullName, onTap: () => editName(context, c)),
              SettingsRow(icon: Icons.phone_iphone_rounded, label: 'Mobile number', value: c.phoneDisplay, onTap: () => editPhone(context, c)),
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: c.email,
                valueMaxLines: 2,
                onTap: () => auth.hasPassword ? editEmail(context, c) : _googleNote(context, 'Your email comes from your Google account, so it cannot be changed here.'),
              ),
              SettingsRow(
                icon: Icons.home_outlined,
                label: 'Home address',
                value: address,
                placeholder: 'Add your home address',
                onTap: () => editAddress(context, c),
              ),
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: 'Change password',
                onTap: () => auth.hasPassword ? changePassword(context) : _googleNote(context, 'You sign in with Google, so there is no app password. Manage your password in your Google account.'),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(title: 'App settings', rows: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.text_fields_rounded, size: 22, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: Text('Text size', style: AppTextStyles.bodyLargeRole)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(left: 22 + AppSpacing.lg),
                    child: SegmentedButton<AppTextScale>(
                      segments: const [
                        ButtonSegment(value: AppTextScale.small, label: Text('Small')),
                        ButtonSegment(value: AppTextScale.medium, label: Text('Medium')),
                        ButtonSegment(value: AppTextScale.large, label: Text('Large')),
                      ],
                      selected: {a11y.textScale},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => a11y.setTextScale(s.first),
                    ),
                  ),
                ]),
              ),
              SettingsRow(icon: Icons.logout_rounded, label: 'Sign out', destructive: true, onTap: () => _signOut(context)),
            ]),
          ]),
        ),
      ),
    );
  }

  static void _googleNote(BuildContext context, String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Signed in with Google'),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  static Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Sign out?', message: 'You can sign back in any time.', confirmLabel: 'Sign out');
    if (ok && context.mounted) await context.read<SessionProvider>().signOut();
  }

  // ------------------------------------------------------------------ editors

  static Future<void> editName(BuildContext context, CustomerModel c) async {
    final first = TextEditingController(text: c.cusFName);
    final middle = TextEditingController(text: c.cusMName);
    final last = TextEditingController(text: c.cusLName);
    final saved = await showEditSheet(
      context,
      title: 'Full name',
      description: 'Your name as it appears on your bookings.',
      isDirty: () => first.text != c.cusFName || middle.text != c.cusMName || last.text != c.cusLName,
      onSave: () => CustomerService().updateName(c.cusID, firstName: first.text, middleName: middle.text, lastName: last.text),
      fields: (_) => Column(children: [
        TextFormField(controller: first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => Validators.required(v, 'First name')),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: middle, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Middle name (optional)')),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name'), validator: (v) => Validators.required(v, 'Last name')),
      ]),
    );
    if (saved && context.mounted) showSuccess(context, 'Name updated.');
  }

  static Future<void> editPhone(BuildContext context, CustomerModel c) async {
    final initial = PhLocalPhoneFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: PhPhone.localDigits(c.phoneNum))).text;
    final phone = TextEditingController(text: initial);
    final saved = await showEditSheet(
      context,
      title: 'Mobile number',
      description: 'The hotel uses this number to reach you about your pet\'s stay.',
      isDirty: () => phone.text != initial,
      onSave: () => CustomerService().updatePhone(c.cusID, PhPhoneField.e164Of(phone) ?? ''),
      fields: (_) => PhPhoneField(controller: phone),
    );
    if (saved && context.mounted) showSuccess(context, 'Mobile number updated.');
  }

  static Future<void> editAddress(BuildContext context, CustomerModel c) async {
    var address = c.phAddress;
    final saved = await showEditSheet(
      context,
      title: 'Home address',
      description: 'Choose your region, province and city, then type your barangay and street.',
      isDirty: () => address.toMap().toString() != c.phAddress.toMap().toString(),
      onSave: () => CustomerService().updateAddress(c.cusID, address),
      fields: (_) => PhAddressFields(initial: c.phAddress, legacyAddress: c.address, onChanged: (a) => address = a),
    );
    if (saved && context.mounted) showSuccess(context, 'Home address updated.');
  }

  static Future<void> editEmail(BuildContext context, CustomerModel c) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final saved = await showEditSheet(
      context,
      title: 'Change email',
      description: 'We will send a confirmation link to the new address. Your email changes only after you open that link.',
      saveLabel: 'Send link',
      isDirty: () => email.text.isNotEmpty || password.text.isNotEmpty,
      onSave: () => AuthService().requestEmailChange(newEmail: email.text, currentPassword: password.text),
      fields: (_) => Column(children: [
        ReadOnlyItem(label: 'Current email', value: c.email, icon: Icons.mail_outline_rounded),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'New email'), validator: Validators.email),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(controller: password, label: 'Current password', validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null),
      ]),
    );
    if (saved && context.mounted) {
      showSuccess(context, 'Check ${email.text.trim()} and open the link to finish changing your email.');
    }
  }

  static Future<void> changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final saved = await showEditSheet(
      context,
      title: 'Change password',
      description: 'For your security, enter your current password first.',
      saveLabel: 'Update password',
      isDirty: () => current.text.isNotEmpty || next.text.isNotEmpty || confirm.text.isNotEmpty,
      onSave: () => AuthService().changePassword(currentPassword: current.text, newPassword: next.text),
      fields: (_) => Column(children: [
        _PasswordField(controller: current, label: 'Current password', validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(
          controller: next,
          label: 'New password (min. 6 characters)',
          validator: (v) => Validators.password(v) ?? ((v ?? '') == current.text ? 'Choose a password different from the current one.' : null),
        ),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(controller: confirm, label: 'Confirm new password', validator: (v) => Validators.confirmPassword(v, next.text)),
      ]),
    );
    if (saved && context.mounted) showSuccess(context, 'Password updated.');
  }
}

class _ProfileHeader extends StatelessWidget {
  final CustomerModel customer;
  final String username;
  const _ProfileHeader({required this.customer, required this.username});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mustardSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: AppBorders.width),
          ),
          child: Text(customer.firstName.isNotEmpty ? customer.firstName[0].toUpperCase() : '?', style: AppTextStyles.headlineSmall),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.fullName, style: AppTextStyles.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (username.isNotEmpty) Text('@$username', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
          ]),
        ),
      ]);
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  const _PasswordField({required this.controller, required this.label, this.validator});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: widget.validator,
      );
}

