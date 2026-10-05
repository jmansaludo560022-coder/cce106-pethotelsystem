import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../core/constants/app_spacing.dart';

/// A-10 QR check-in / check-out (QR-002 … QR-006; spec §7.9).
///
/// Every scan is verified against Firestore — the QR only carries the booking
/// reference and the action. The admin sees the booking and whether the action
/// is allowed (status + date window, Q-16) before confirming; the final status
/// change runs in a transaction so duplicate or simultaneous scans cannot
/// repeat a transition.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final BookingService _svc = BookingService();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw != null && raw.isNotEmpty) _handle(raw);
  }

  Future<void> _handle(String raw) async {
    final payload = QrPayload.parse(raw);
    if (payload == null) {
      await _result(false, 'Not a Pet Hotel pass', 'This QR code is not a valid Pet Hotel check-in or check-out pass.');
      return;
    }
    await _review(payload);
  }

  /// Loads the booking and asks the admin to confirm the action.
  Future<void> _review(QrPayload payload) async {
    setState(() => _busy = true);
    await _controller.stop();
    try {
      final b = await _svc.getBooking(payload.bookingID);
      if (!mounted) return;
      if (b == null) {
        await _result(false, 'Booking not found', 'No booking matches this pass. Ask the customer to refresh their pass.');
        return;
      }
      final preview = evaluateQrScan(action: payload.action, status: b.status, checkIn: b.checkInDate, checkOut: b.checkOutDate);
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ConfirmSheet(booking: b, action: payload.action, decision: preview),
      );
      if (confirmed == true) {
        final res = await _svc.processScan(payload);
        if (!mounted) return;
        await _result(res.decision.allowed, res.decision.allowed ? res.decision.message : 'Not allowed', res.decision.allowed ? '${b.petLabel} · ${b.roomLabel}' : res.decision.message);
      }
    } catch (e) {
      if (mounted) await _result(false, 'Scan failed', friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _controller.start();
      }
    }
  }

  Future<void> _result(bool ok, String title, String message) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 48, color: ok ? AppColors.success : AppColors.error),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  /// QR-006: manual lookup by booking reference (the 8-character ref shown on
  /// passes and admin cards) or the full booking ID. Useful for walk-ins.
  Future<void> _manual() async {
    final ref = await promptDialog(context, title: 'Manual reference lookup', hint: 'Booking ref, e.g. 7F3KQ2AB', confirmLabel: 'Find');
    if (ref == null || ref.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final all = await _svc.streamAll().first;
      final q = ref.trim();
      final b = all.where((x) => x.bookingID == q || Fmt.ref(x.bookingID) == q.toUpperCase()).firstOrNull;
      if (!mounted) return;
      setState(() => _busy = false);
      if (b == null) {
        await _result(false, 'Booking not found', 'No booking has the reference "$q".');
        return;
      }
      final action = b.isCheckedIn ? QrAction.checkOut : QrAction.checkIn;
      await _review(QrPayload(b.bookingID, action));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        await _result(false, 'Lookup failed', friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Container(
            color: AppColors.ink,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined, color: AppColors.onInk, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Camera unavailable', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onInk)),
              const SizedBox(height: 6),
              Text('Allow camera access, or use Manual lookup below.\n(${error.errorCode.name})',
                  textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.borderMedium)),
            ]),
          ),
        ),
      ),
      Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 4), borderRadius: BorderRadius.circular(24)),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: Row(children: [
          _roundButton(Icons.flash_on_rounded, 'Toggle flashlight', () => _controller.toggleTorch()),
          const SizedBox(width: AppSpacing.sm),
          _roundButton(Icons.cameraswitch_rounded, 'Switch camera', () => _controller.switchCamera()),
        ]),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 24,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
            decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(14)),
            child: const Text(
              'Align the customer\'s Check-in or Check-out QR inside the frame.',
              textAlign: TextAlign.center,
              style: AppTextStyles.onInkBody,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Manual reference lookup', icon: Icons.keyboard_alt_outlined, fullWidth: false, isLoading: _busy, onPressed: _manual),
        ]),
      ),
    ]);
  }

  Widget _roundButton(IconData icon, String tip, VoidCallback onTap) => IconButton.filled(
        tooltip: tip,
        style: IconButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.ink),
        onPressed: onTap,
        icon: Icon(icon),
      );
}

class _ConfirmSheet extends StatelessWidget {
  final BookingModel booking;
  final QrAction action;
  final QrDecision decision;
  const _ConfirmSheet({required this.booking, required this.action, required this.decision});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isIn = action == QrAction.checkIn;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(isIn ? 'Check-in pass' : 'Check-out pass', style: AppTextStyles.headingMedium)),
            StatusBadge(status: b.status),
          ]),
          const SizedBox(height: 10),
          InfoRow('Customer', b.customerName),
          InfoRow('Pet', b.petType.isNotEmpty ? '${b.petLabel} (${b.petType})' : b.petLabel),
          InfoRow('Room', '${b.roomLabel} · ${b.roomTypeName}'),
          InfoRow('Stay', Fmt.range(b.checkInDate, b.checkOutDate)),
          InfoRow('Booking ref', Fmt.ref(b.bookingID)),
          const SizedBox(height: AppSpacing.md),
          TintedCard(
            tintColor: decision.allowed ? AppColors.successBg : AppColors.errorBg,
            child: Row(children: [
              Icon(decision.allowed ? Icons.verified_rounded : Icons.block_rounded, color: decision.allowed ? AppColors.successText : AppColors.errorText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  decision.allowed ? (isIn ? 'Ready to check in.' : 'Ready to check out.') : decision.message,
                  style: AppTextStyles.labelMedium.copyWith(color: decision.allowed ? AppColors.successText : AppColors.errorText),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: SecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context, false))),
            if (decision.allowed) ...[
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton(label: isIn ? 'Confirm check-in' : 'Confirm check-out', onPressed: () => Navigator.pop(context, true))),
            ],
          ]),
        ]),
      ),
    );
  }
}
