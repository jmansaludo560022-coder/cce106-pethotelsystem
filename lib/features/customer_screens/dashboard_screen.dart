import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/review_model.dart';
import '../../providers/session_provider.dart';
import '../../services/catalog_service.dart';
import '../../services/review_service.dart';
import 'room_catalog.dart';
import 'room_details.dart';
import 'room_widgets.dart';
import 'services_row.dart';

/// C-01 Customer Home (Enhancement Spec §9.1, Figma "Home Page"), top to
/// bottom: header, search, browse rooms, services, reviews. The current stay
/// lives in My Bookings and the pets in My Pets (owner request, 2026-10-03). (The "Why pet parents choose us" tiles were removed
/// at the owner's request, 2026-10-03.) Every section shows real data and has
/// a compact empty state, so the page is never blank.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late final Stream<List<ReviewModel>> _reviews = ReviewService().streamAll();
  void _openBrowse() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrowseRoomsScreen()));

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<SessionProvider>().customer;
    final today = dateOnly(DateTime.now());
    const gap = SizedBox(height: AppSpacing.xxl);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CatalogLoader(builder: (context, rooms, types, res) {
          final items = RoomAvailability.compute(rooms: rooms, types: types, reservations: res, checkIn: today, checkOut: today.add(const Duration(days: 1)));
          return MaxWidth(
            maxWidth: 720,
            child: ListView(padding: const EdgeInsets.only(bottom: AppSpacing.xxl), children: [
              PageHeader(
                title: 'Hi, ${customer?.firstName.isNotEmpty == true ? customer!.firstName : 'there'}!',
                subtitle: "Ready for your pet's next stay?",
                leading: _Avatar(name: customer?.firstName ?? ''),
              ),
              _Section(child: _SearchPill(onTap: _openBrowse)),
              gap,
              _Section(
                child: SectionHeader('Browse rooms', subtitle: 'Live availability for tonight', actionLabel: 'See all', onAction: _openBrowse),
              ),
              _RoomsRow(items: items),
              gap,
              const _Section(child: ServicesRow()),
              _Section(child: _ReviewsSection(stream: _reviews)),
            ]),
          );
        }),
      ),
    );
  }
}

/// Standard 20 dp side margin for a Home section.
class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: child);
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mustardSoft,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: AppBorders.width),
        ),
        child: name.isEmpty
            ? const Icon(Icons.person_rounded, color: AppColors.ink)
            : Text(name[0].toUpperCase(), style: AppTextStyles.titleLarge),
      );
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Search rooms',
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: const BorderSide(color: AppColors.ink, width: AppBorders.width),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Search rooms…', style: AppTextStyles.bodyLargeRole.copyWith(color: AppColors.inkMuted))),
                const Icon(Icons.tune_rounded, color: AppColors.ink),
              ]),
            ),
          ),
        ),
      );
}

class _RoomsRow extends StatelessWidget {
  final List<RoomAvailability> items;
  const _RoomsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Section(
        child: AppCard(
          child: Row(children: [
            const Mascot(pose: MascotPose.sleep, size: 72),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('New rooms are coming soon', style: AppTextStyles.titleMedium),
                Text('The hotel has not published any rooms yet. Please check back later.', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
              ]),
            ),
          ]),
        ),
      );
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 214 + 40 * (scale - 1).clamp(0, 1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) => SizedBox(width: 208, child: _RoomCard(item: items[i])),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomAvailability item;
  const _RoomCard({required this.item});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomDetailsScreen(roomID: item.room.roomID))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AppImage(url: item.room.roomPhoto, height: 112, width: double.infinity, radius: 0, fallbackIcon: Icons.meeting_room_rounded),
            Positioned(top: AppSpacing.sm, left: AppSpacing.sm, child: SlotsBadge(item: item)),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.typeName, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Room ${item.room.roomNum} · up to ${item.capacity} pet${item.capacity == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: Fmt.pesoShort(item.price), style: AppTextStyles.priceSmall),
                  TextSpan(text: ' / night', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
                ]),
                maxLines: 1,
              ),
            ]),
          ),
        ]),
      );
}

class _ReviewsSection extends StatelessWidget {
  final Stream<List<ReviewModel>> stream;
  const _ReviewsSection({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final reviews = snap.data ?? const <ReviewModel>[];
        final avg = reviews.isEmpty ? 0.0 : reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            'Customer reviews',
            subtitle: reviews.isEmpty ? 'What pet parents say about their stay' : '${avg.toStringAsFixed(1)} ★ from ${reviews.length} review${reviews.length == 1 ? '' : 's'}',
          ),
          if (!snap.hasData)
            const SizedBox(height: 56, child: Center(child: PawLoader()))
          else if (reviews.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(children: [
                const Icon(Icons.rate_review_outlined, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('No reviews yet. Reviews appear here after guests complete their stay.', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted))),
              ]),
            )
          else
            // Cards size to their content; the row scrolls sideways.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < reviews.take(6).length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    SizedBox(width: 264, child: ReviewCard(review: reviews[i], maxCommentLines: 4)),
                  ],
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const StarRow({super.key, required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${rating.toStringAsFixed(1)} out of 5 stars',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final icon = rating >= i + 1 ? Icons.star_rounded : (rating > i ? Icons.star_half_rounded : Icons.star_outline_rounded);
            return Icon(icon, size: size, color: AppColors.warning);
          }),
        ),
      );
}

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final Widget? trailing;

  /// Limit the comment (horizontal Home row); null shows it in full.
  final int? maxCommentLines;
  const ReviewCard({super.key, required this.review, this.trailing, this.maxCommentLines});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryContainer,
              child: Text(review.custName.isNotEmpty ? review.custName[0].toUpperCase() : '?', style: AppTextStyles.labelLarge),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(review.custName, style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis),
                Text(
                  [if ((review.roomTypeName ?? '').isNotEmpty) review.roomTypeName!, if ((review.petName ?? '').isNotEmpty) review.petName!, Fmt.date(review.createdAt)].join(' · '),
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            ?trailing,
          ]),
          const SizedBox(height: AppSpacing.sm),
          StarRow(rating: review.rating, size: 16),
          const SizedBox(height: AppSpacing.xs),
          if (review.title.isNotEmpty) Text(review.title, style: AppTextStyles.labelMedium),
          Text(
            review.comment,
            style: AppTextStyles.bodyMedium,
            maxLines: maxCommentLines,
            overflow: maxCommentLines == null ? null : TextOverflow.ellipsis,
          ),
        ]),
      );
}
