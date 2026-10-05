import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../models/pet_model.dart';
import '../../providers/session_provider.dart';
import '../../services/pet_service.dart';
import 'booking_wizard.dart';
import 'pet_registration.dart';
import '../../core/constants/app_spacing.dart';

/// C-02 My Pets (PET-001, PET-006, PET-007; Figma "Pets"): one card per pet
/// with Edit Profile / Delete / Book. The list is real-time, so a newly saved
/// pet appears immediately (fixes ISS-17/ISS-18).
class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  String? _cusID;
  late Stream<List<PetModel>> _pets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<SessionProvider>().cusID;
    if (id != null && id != _cusID) {
      _cusID = id;
      _pets = PetService().streamForCustomer(id);
    }
  }

  void _add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetFormScreen(cusID: _cusID!)));

  Future<void> _delete(PetModel p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${p.petName}?',
      message: 'This removes the pet profile. Pets with active bookings cannot be deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await PetService().deletePet(p);
      if (mounted) showSuccess(context, '${p.petName} was removed.');
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cusID == null) return const Scaffold(body: LoadingState());
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MaxWidth(
              child: PageHeader(
                title: 'My Pets',
                subtitle: 'Profiles used for your bookings',
                trailing: SecondaryButton(label: 'Add pet', icon: Icons.add_rounded, fullWidth: false, onPressed: _add),
              ),
            ),
            Expanded(
              child: StreamStateBuilder<List<PetModel>>(
                stream: _pets,
                onRetry: () => setState(() => _pets = PetService().streamForCustomer(_cusID!)),
                loadingMessage: 'Loading your pets…',
                errorTitle: 'Unable to load pets',
                builder: (context, pets) {
                  if (pets.isEmpty) {
                    return EmptyState(
                      icon: Icons.pets_rounded,
                      mascot: MascotPose.sleep,
                      topAligned: true,
                      title: 'No pets yet',
                      message: 'Register your pet to start booking stays.',
                      actionLabel: 'Register a pet',
                      onAction: _add,
                    );
                  }
                  return MaxWidth(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl),
                      itemCount: pets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => PetCard(
                        pet: pets[i],
                        actions: [
                          SecondaryButton(
                            label: 'Edit',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PetFormScreen(cusID: _cusID!, existing: pets[i]),
                              ),
                            ),
                          ),
                          DestructiveButton(label: 'Delete', onPressed: () => _delete(pets[i])),
                          PrimaryButton(
                            label: 'Book',
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingWizardScreen(initialPetID: pets[i].petID))),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pet card shared by customer and admin pet lists.
class PetCard extends StatelessWidget {
  final PetModel pet;
  final List<Widget> actions;
  final String? ownerName;
  final VoidCallback? onTap;
  const PetCard({super.key, required this.pet, this.actions = const [], this.ownerName, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(url: pet.petPhoto, width: 76, height: 76),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(pet.petName, style: AppTextStyles.headingSmall, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: StatusBadge(
                            status: pet.hasVaccinationRecord ? pet.vaccinationBadgeStatus : 'pending',
                            label: pet.vaccinationBadgeLabel,
                          ),
                        ),
                      ],
                    ),
                    Text(pet.subtitle, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                    if (ownerName != null) Text('Owner: $ownerName', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                    if (pet.isVaccinationRejected && pet.vaccinationNote.isNotEmpty)
                      Text('Vaccination file rejected: ${pet.vaccinationNote}. Edit the pet to upload a new file.', style: AppTextStyles.caption.copyWith(color: AppColors.errorText), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagChip(pet.petType, color: AppColors.chipYellow),
                        TagChip(pet.sizeLabel, color: AppColors.chipBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: AppSpacing.sm), Expanded(child: actions[i])],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
