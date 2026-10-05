import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/ph_locations.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/ph_form_fields.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';

/// S-02 Sign In and S-03 Create Account (AUTH-002, AUTH-003, AUTH-005).
/// Owner requests (2026-10-03): no "Sign In" / "Create Account" page titles,
/// centred content, and a choice of Google or email + password. After
/// success the stack is popped back to the AuthGate, which opens the admin
/// or customer area by role (or "Complete your profile" for a new Google user).

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signIn(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter your account email. We will send you a link to set a new password.'),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (Validators.email(email) != null) {
      showError(context, 'Enter a valid email address.');
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) showSuccess(context, 'If an account exists for $email, a reset link has been sent.');
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _CenteredAuthBody(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _AuthHeader(title: 'Welcome back!', subtitle: 'Sign in to manage your pets and bookings.'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required.' : null,
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?'))),
              const SizedBox(height: AppSpacing.xs),
              PrimaryButton(label: 'Sign in', isLoading: _loading, onPressed: _submit),
              const _OrDivider(),
              GoogleSignInButton(label: 'Continue with Google', enabled: !_loading),
              const SizedBox(height: AppSpacing.lg),
              _SwitchLink(
                question: "Don't have an account? ",
                action: 'Sign up',
                onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Two-step sign-up (owner request): Step 1 collects personal info and the
/// address; Step 2 creates the login (email, username, password + confirm).
/// Both steps stay alive in an IndexedStack, so going Back keeps every value.
class _RegisterScreenState extends State<RegisterScreen> {
  final _personalForm = GlobalKey<FormState>();
  final _accountForm = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  PhAddress _address = PhAddress.empty;
  final _auth = AuthService();
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  static const _steps = ['Personal info', 'Login details'];

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _phone, _email, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (!_personalForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() => _step = 0);
  }

  Future<void> _submit() async {
    if (!_accountForm.currentState!.validate()) return;
    // Safety net: Step 1 must still be valid.
    if (!_personalForm.currentState!.validate()) {
      setState(() => _step = 0);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.registerCustomer(
        email: _email.text,
        password: _password.text,
        username: _username.text,
        firstName: _first.text,
        middleName: _middle.text,
        lastName: _last.text,
        phone: PhPhoneField.e164Of(_phone) ?? '',
        address: _address,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 && !_loading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1 && !_loading) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          // Step progress in place of a page title (owner: no "Create Account" heading).
          title: _StepProgress(step: _step, labels: _steps),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _step, children: [_personalStep(), _accountStep()]),
        ),
      ),
    );
  }

  Widget _personalStep() {
    const gap = SizedBox(height: AppSpacing.md);
    return _CenteredAuthBody(
      child: Form(
        key: _personalForm,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _AuthHeader(title: 'Join the Pet Hotel', subtitle: 'First, tell us about yourself.'),
          TextFormField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(labelText: 'First name'),
            validator: (v) => Validators.required(v, 'First name'),
          ),
          gap,
          TextFormField(
            controller: _middle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Middle name (optional)'),
          ),
          gap,
          TextFormField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            decoration: const InputDecoration(labelText: 'Last name'),
            validator: (v) => Validators.required(v, 'Last name'),
          ),
          gap,
          PhPhoneField(controller: _phone, textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.xl),
          Text('Home address', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PhAddressFields(initial: _address, onChanged: (a) => _address = a),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'Next', icon: Icons.arrow_forward_rounded, onPressed: _next),
          const _OrDivider(),
          GoogleSignInButton(label: 'Sign up with Google', enabled: !_loading),
          const SizedBox(height: AppSpacing.lg),
          _signInLink(),
        ]),
      ),
    );
  }

  Widget _accountStep() {
    const gap = SizedBox(height: AppSpacing.md);
    return _CenteredAuthBody(
      child: Form(
        key: _accountForm,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _AuthHeader(title: 'Create your login', subtitle: 'You will use your email and password to sign in.'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: Validators.email,
          ),
          gap,
          TextFormField(
            controller: _username,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded)),
            validator: (v) => Validators.required(v, 'Username'),
          ),
          gap,
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password (min. 6 characters)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: Validators.password,
          ),
          gap,
          TextFormField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) => Validators.confirmPassword(v, _password.text),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(child: SecondaryButton(label: 'Back', icon: Icons.arrow_back_rounded, onPressed: _loading ? null : _back)),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 2, child: PrimaryButton(label: 'Create account', isLoading: _loading, onPressed: _submit)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _signInLink(),
        ]),
      ),
    );
  }

  Widget _signInLink() => _SwitchLink(
        question: 'Already have an account? ',
        action: 'Sign in',
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
      );
}

/// Centres the form on the screen (owner request) and keeps it a readable
/// width on tablets and the web; scrolls when the keyboard is open.
class _CenteredAuthBody extends StatelessWidget {
  final Widget child;
  const _CenteredAuthBody({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (c.maxHeight - AppSpacing.xxl).clamp(0, double.infinity)),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: child)),
          ),
        ),
      );
}

class _AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AuthHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(children: [
          const Mascot(pose: MascotPose.head, size: 64),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTextStyles.bodyMediumRole.copyWith(color: AppColors.inkMuted), textAlign: TextAlign.center),
        ]),
      );
}

class _StepProgress extends StatelessWidget {
  final int step;
  final List<String> labels;
  const _StepProgress({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Step ${step + 1} of ${labels.length}: ${labels[step]}',
        excludeSemantics: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Step ${step + 1} of ${labels.length} · ${labels[step]}', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.xs + 2),
          SizedBox(
            width: 160,
            child: Row(children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.normal),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.mustard : AppColors.line,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('or continue with', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

class _SwitchLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;
  const _SwitchLink({required this.question, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(question, style: AppTextStyles.bodyMedium),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                child: Text(action, style: AppTextStyles.linkBold),
              ),
            ),
          ),
        ]),
      );
}

/// "Continue with Google" (owner decision: Google + email/password), using
/// Firebase Authentication. Closing the Google window simply does nothing;
/// errors are shown in plain language. A brand-new Google user is taken to
/// "Complete your profile" by the AuthGate.
class GoogleSignInButton extends StatefulWidget {
  final String label;
  final bool enabled;
  const GoogleSignInButton({super.key, required this.label, this.enabled = true});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      final signedIn = await AuthService().signInWithGoogle();
      if (signedIn && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: widget.enabled && !_busy ? _go : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.ink, width: AppBorders.width),
          shape: const StadiumBorder(),
        ),
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/brand/google_g.svg', width: 18, height: 18, excludeFromSemantics: true),
                const SizedBox(width: AppSpacing.md),
                Text(widget.label, style: AppTextStyles.labelLargeRole),
              ]),
      );
}
