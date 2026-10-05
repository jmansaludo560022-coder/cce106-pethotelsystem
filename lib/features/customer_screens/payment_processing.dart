import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../services/payment_service.dart';
import '../../core/constants/app_spacing.dart';

/// "Pay Now" for an unpaid balance (Figma Bookings → Pay Now; Q-07).
///
/// IMPORTANT: this is a SIMULATED e-wallet — no GCash/Maya integration exists,
/// no money moves, and the payment is stored with isSimulated = true so the
/// admin can tell it apart from real counter payments.
class PayNowScreen extends StatefulWidget {
  final BookingModel booking;
  final double balance;
  const PayNowScreen({super.key, required this.booking, required this.balance});

  @override
  State<PayNowScreen> createState() => _PayNowScreenState();
}

class _PayNowScreenState extends State<PayNowScreen> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await PaymentService().recordPayment(
        booking: widget.booking,
        amount: widget.balance,
        method: PaymentMethods.eWalletSimulated,
        isSimulated: true,
        recordedBy: 'customer',
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Simulated payment recorded. Your booking is now marked as paid.');
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Now')),
      body: MaxWidth(
        maxWidth: 520,
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
          AppCard(
            child: Column(children: [
              InfoRow('Booking', 'Ref ${Fmt.ref(b.bookingID)}'),
              InfoRow('Room', '${b.roomLabel} · ${b.roomTypeName}'),
              InfoRow('Pet', b.petLabel),
              const Divider(height: 18),
              InfoRow('Amount due', Fmt.peso(widget.balance), emphasize: true),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          const TintedCard(
            tintColor: AppColors.warningBg,
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warningText),
              SizedBox(width: 10),
              Expanded(
                child: Text('Simulated e-wallet for demonstration only. No real GCash or Maya payment is made.',
                    style: AppTextStyles.warningBanner),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
              child: QrImageView(data: 'SIMULATED-EWALLET:${b.bookingID}:${widget.balance.toStringAsFixed(2)}', size: 170),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Center(child: Text('Scan to pay (simulated)', style: AppTextStyles.caption)),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Confirm simulated payment', isLoading: _paying, onPressed: _pay),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Pay at the front desk instead', onPressed: _paying ? null : () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
