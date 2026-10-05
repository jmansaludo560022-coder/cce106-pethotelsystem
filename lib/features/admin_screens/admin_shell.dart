import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/session_provider.dart';
import 'add_ons.dart';
import 'admin_reviews_management.dart';
import 'booking_management.dart';
import 'dashboard.dart';
import 'payments.dart';
import 'pet_management.dart';
import 'qr_scanner_screen.dart';
import 'rooms_tabs.dart';
import '../../core/constants/app_spacing.dart';

/// Admin area (NAV-002; spec §4.6, Q-03 approved): a left menu drawer on phones
/// and a permanent sidebar on wide screens, with every admin module, a page
/// title on each module and Sign out. The old "Customer View" switch was
/// removed (Q-19) so the two roles stay separate.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

enum AdminModule { dashboard, bookings, rooms, pets, addOns, payments, reviews, scanner }

class _ModuleInfo {
  final String title;
  final String menuLabel;
  final IconData icon;
  const _ModuleInfo(this.title, this.menuLabel, this.icon);
}

const _modules = {
  AdminModule.dashboard: _ModuleInfo('Admin Dashboard', 'Dashboard', Icons.dashboard_outlined),
  AdminModule.bookings: _ModuleInfo('Bookings', 'Bookings', Icons.calendar_month_outlined),
  AdminModule.rooms: _ModuleInfo('Rooms & Room Types', 'Rooms & Room Types', Icons.meeting_room_outlined),
  AdminModule.pets: _ModuleInfo('Pets', 'Pets', Icons.pets_outlined),
  AdminModule.addOns: _ModuleInfo('Add-on Services', 'Add-on Services', Icons.spa_outlined),
  AdminModule.payments: _ModuleInfo('Payments', 'Payments', Icons.payments_outlined),
  AdminModule.reviews: _ModuleInfo('Reviews', 'Reviews', Icons.rate_review_outlined),
  AdminModule.scanner: _ModuleInfo('QR Check-in / Check-out', 'QR Scanner', Icons.qr_code_scanner_rounded),
};

class _AdminShellState extends State<AdminShell> {
  AdminModule _current = AdminModule.dashboard;

  /// null = follow the screen width; set when the admin toggles the rail.
  bool? _railExpanded;

  void _go(AdminModule m) => setState(() => _current = m);

  Widget _body() {
    switch (_current) {
      case AdminModule.dashboard:
        return AdminDashboardScreen(onNavigate: _go);
      case AdminModule.bookings:
        return const AdminBookingsScreen();
      case AdminModule.rooms:
        return const RoomsManagementScreen();
      case AdminModule.pets:
        return const AdminPetsScreen();
      case AdminModule.addOns:
        return const AddOnsManagementScreen();
      case AdminModule.payments:
        return const PaymentsScreen();
      case AdminModule.reviews:
        return const AdminReviewsScreen();
      case AdminModule.scanner:
        return const QrScannerScreen();
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context, title: 'Sign out?', message: 'You will return to the sign-in screen.', confirmLabel: 'Sign out');
    if (ok && mounted) await context.read<SessionProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layout = AdminNavLayout.forWidth(width);
    final user = context.watch<SessionProvider>().user;
    final railExpanded = _railExpanded ?? layout == AdminNavLayout.expandedRail;

    AdminNavMenu menu({required bool collapsed, required bool inDrawer}) => AdminNavMenu(
          current: _current,
          collapsed: collapsed,
          username: user?.username ?? '',
          email: user?.email ?? '',
          onSelect: (m) {
            if (inDrawer) Navigator.of(context).pop();
            _go(m);
          },
          onSignOut: _signOut,
          onToggleCollapse: inDrawer ? null : () => setState(() => _railExpanded = !railExpanded),
        );

    // Back button on a module other than the dashboard returns to the dashboard.
    return PopScope(
      canPop: _current == AdminModule.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(AdminModule.dashboard);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_modules[_current]!.title),
          automaticallyImplyLeading: layout == AdminNavLayout.drawer,
        ),
        // D10: phones get a compact drawer that leaves room for the content.
        drawer: layout == AdminNavLayout.drawer
            ? Drawer(width: AdminNavLayout.drawerWidth(width), child: menu(collapsed: false, inDrawer: true))
            : null,
        body: layout == AdminNavLayout.drawer
            ? KeyedSubtree(key: ValueKey(_current), child: _body())
            : Row(children: [
                // D10: 72 dp icon rail, expandable to a 240 dp labelled panel.
                Container(
                  width: railExpanded ? AdminNavLayout.expandedWidth : AdminNavLayout.railWidth,
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                  child: menu(collapsed: !railExpanded, inDrawer: false),
                ),
                Expanded(child: KeyedSubtree(key: ValueKey(_current), child: _body())),
              ]),
      ),
    );
  }
}

/// Responsive admin navigation (decision D10, spec §6 window sizes):
/// < 600 dp: compact drawer; 600-999 dp: collapsed 72 dp rail;
/// >= 1000 dp: expanded 240 dp panel. The rail can be toggled at any width.
enum AdminNavLayout {
  drawer,
  collapsedRail,
  expandedRail;

  static const double railWidth = 72;
  static const double expandedWidth = 240;

  static AdminNavLayout forWidth(double w) => w < 600 ? drawer : (w < 1000 ? collapsedRail : expandedRail);

  /// Phone drawer: at most 256 dp and never more than 75% of the screen.
  static double drawerWidth(double screenWidth) => screenWidth * 0.75 < 256 ? screenWidth * 0.75 : 256;
}

/// The admin menu (same items and destinations as before). [collapsed] shows
/// icons only, each with a tooltip and the same selected-state pill.
class AdminNavMenu extends StatelessWidget {
  final AdminModule current;
  final bool collapsed;
  final String username;
  final String email;
  final ValueChanged<AdminModule> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback? onToggleCollapse;

  const AdminNavMenu({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onSignOut,
    this.collapsed = false,
    this.username = '',
    this.email = '',
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final name = username.isNotEmpty ? username : 'Administrator';
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Compact profile header (menu reference, SRC-F p.5).
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: collapsed
                ? Tooltip(
                    message: '$name (Admin)',
                    child: const CircleAvatar(radius: 22, backgroundColor: AppColors.primary, child: Icon(Icons.pets_rounded, color: AppColors.ink, size: 22)),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.pets_rounded, color: AppColors.ink, size: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: AppTextStyles.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(email.isNotEmpty ? email : 'Pet Hotel Admin', style: AppTextStyles.captionSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  ),
          ),
          if (onToggleCollapse != null)
            Align(
              alignment: collapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
                icon: Icon(collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded),
                onPressed: onToggleCollapse,
              ),
            ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs), children: [
              for (final m in AdminModule.values) ...[
                if (m == AdminModule.reviews) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
                _item(m),
              ],
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _tile(icon: Icons.logout_rounded, label: 'Sign out', color: AppColors.errorText, selected: false, onTap: onSignOut),
          ),
        ]),
      ),
    );
  }

  Widget _item(AdminModule m) {
    final info = _modules[m]!;
    final active = m == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _tile(
        icon: info.icon,
        label: info.menuLabel,
        color: active ? AppColors.textPrimary : AppColors.textSecondary,
        selected: active,
        onTap: () => onSelect(m),
      ),
    );
  }

  /// 48 dp tall row; the selected item gets the mustard pill. Collapsed rows
  /// show the icon only, with the label as tooltip and semantics label.
  Widget _tile({required IconData icon, required String label, required Color color, required bool selected, required VoidCallback onTap}) {
    final iconColor = selected ? AppColors.textPrimary : (color == AppColors.errorText ? color : AppColors.textMuted);
    final content = collapsed
        ? Center(child: Icon(icon, size: 22, color: iconColor))
        : Row(children: [
            const SizedBox(width: AppSpacing.md),
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (selected ? AppTextStyles.menuItemActive : AppTextStyles.menuItem).copyWith(color: color)),
            ),
          ]);
    final tile = Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(height: 48, child: content),
        ),
      ),
    );
    return collapsed ? Tooltip(message: label, preferBelow: false, child: tile) : tile;
  }
}
