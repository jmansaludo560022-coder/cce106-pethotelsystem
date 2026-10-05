import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_views.dart';
import '../../core/widgets/pressable.dart';
import '../../models/booking_model.dart';
import '../../providers/session_provider.dart';
import '../../services/booking_service.dart';
import 'booking_wizard.dart';
import 'dashboard_screen.dart';
import 'edit_profile.dart';
import 'my_bookings.dart';
import 'pets_list_screen.dart';
import '../../core/constants/app_spacing.dart';

/// Customer area with the bottom navigation bar (NAV-001, Q-02 approved):
/// Home · Pets · Book (raised centre button) · Bookings · Account.
/// Reviews live inside My Bookings (SRC-C p.17 / Figma note).
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  /// Screens pushed on top of the shell (e.g. the booking wizard) can ask the
  /// shell to show a tab after they close.
  static final ValueNotifier<CustomerTab?> tabRequest = ValueNotifier(null);

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

enum CustomerTab { home, pets, bookings, account }

class _CustomerShellState extends State<CustomerShell> {
  CustomerTab _tab = CustomerTab.home;
  String? _cusID;
  Stream<List<BookingModel>>? _bookings;

  @override
  void initState() {
    super.initState();
    CustomerShell.tabRequest.addListener(_onRequest);
  }

  @override
  void dispose() {
    CustomerShell.tabRequest.removeListener(_onRequest);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<SessionProvider>().cusID;
    if (id != null && id != _cusID) {
      _cusID = id;
      _bookings = BookingService().streamForCustomer(id);
    }
  }

  void _onRequest() {
    final t = CustomerShell.tabRequest.value;
    if (t != null && mounted) {
      setState(() => _tab = t);
      CustomerShell.tabRequest.value = null;
    }
  }

  void _switch(CustomerTab t) => setState(() => _tab = t);

  void _openBooking() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingWizardScreen()));

  @override
  Widget build(BuildContext context) {
    final pages = {
      CustomerTab.home: const CustomerHomeScreen(),
      CustomerTab.pets: const PetsScreen(),
      CustomerTab.bookings: const MyBookingsScreen(),
      CustomerTab.account: const AccountScreen(),
    };
    return CustomerShellScope(
      switchTab: _switch,
      child: Scaffold(
        body: IndexedStack(
          index: CustomerTab.values.indexOf(_tab),
          children: CustomerTab.values.map((t) => pages[t]!).toList(),
        ),
        bottomNavigationBar: StreamBuilder<List<BookingModel>>(
          stream: _bookings,
          builder: (context, snap) => CustomerNavBar(
            current: _tab,
            onSelect: _switch,
            onBook: _openBooking,
            hasUpcoming: BookingViews.upcoming(snap.data ?? const []).isNotEmpty,
          ),
        ),
      ),
    );
  }
}

/// Lets nested screens switch tabs (e.g. "View My Bookings" after booking).
class CustomerShellScope extends InheritedWidget {
  final void Function(CustomerTab) switchTab;
  const CustomerShellScope({super.key, required this.switchTab, required super.child});

  static CustomerShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CustomerShellScope>();

  @override
  bool updateShouldNotify(CustomerShellScope oldWidget) => false;
}

/// Floating customer navigation bar (Enhancement Spec §6): white, 20 dp
/// radius, 1.5 px ink outline, 12 dp from the edges; raised mustard "Book"
/// button with the pop shadow; active tab = mustard-soft pill + filled icon
/// with a quick 150 ms bounce; orange dot on Bookings for an upcoming stay.
class CustomerNavBar extends StatelessWidget {
  final CustomerTab current;
  final ValueChanged<CustomerTab> onSelect;
  final VoidCallback onBook;
  final bool hasUpcoming;
  const CustomerNavBar({super.key, required this.current, required this.onSelect, required this.onBook, this.hasUpcoming = false});

  @override
  Widget build(BuildContext context) {
    Widget item(CustomerTab t, IconData icon, IconData activeIcon, String label, {bool dot = false}) => Expanded(
          child: _NavItem(
            active: current == t,
            icon: icon,
            activeIcon: activeIcon,
            label: label,
            dot: dot,
            onTap: () => onSelect(t),
          ),
        );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.ink, width: AppBorders.width),
          ),
          child: Row(children: [
            item(CustomerTab.home, Icons.home_outlined, Icons.home_rounded, 'Home'),
            item(CustomerTab.pets, Icons.pets_outlined, Icons.pets_rounded, 'Pets'),
            Expanded(child: _BookButton(onTap: onBook)),
            item(CustomerTab.bookings, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Bookings', dot: hasUpcoming),
            item(CustomerTab.account, Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool dot;
  final VoidCallback onTap;
  const _NavItem({required this.active, required this.icon, required this.activeIcon, required this.label, required this.dot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fast = AppMotion.of(context, AppMotion.fast);
    return Semantics(
      selected: active,
      button: true,
      label: dot ? '$label, upcoming stay' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Re-keyed on activation so the icon bounces once (skipped with reduced motion).
          TweenAnimationBuilder<double>(
            key: ValueKey(active),
            tween: Tween(begin: active && fast > Duration.zero ? 0.8 : 1, end: 1),
            duration: fast,
            curve: Curves.easeOutBack,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: AnimatedContainer(
              duration: fast,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs / 2),
              decoration: BoxDecoration(color: active ? AppColors.mustardSoft : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Badge(
                isLabelVisible: dot,
                smallSize: 8,
                backgroundColor: AppColors.orange,
                child: Icon(active ? activeIcon : icon, size: 22, color: active ? AppColors.ink : AppColors.inkMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(label, maxLines: 1, overflow: TextOverflow.clip, style: active ? AppTextStyles.navLabelActive : AppTextStyles.navLabel),
        ]),
      ),
    );
  }
}

class _BookButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BookButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Book a stay',
        excludeSemantics: true,
        child: Center(
          child: Pressable(
            builder: (context, pressed) => GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                width: 52,
                height: 52,
                transform: Matrix4.translationValues(0, pressed ? -8 : -10, 0),
                decoration: BoxDecoration(
                  color: AppColors.mustard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: AppBorders.width),
                  boxShadow: pressed ? AppShadows.popPressed : AppShadows.pop,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.ink, size: 28),
              ),
            ),
          ),
        ),
      );
}
