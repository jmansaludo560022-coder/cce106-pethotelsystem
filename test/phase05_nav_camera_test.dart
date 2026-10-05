import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/widgets/camera_capture_screen.dart';
import 'package:flutter_pethotelbooking/features/admin_screens/admin_shell.dart';

/// Phase 0.5: defect #4 (camera fallback) and #5 (admin navigation width).
void main() {
  group('Defect #5: admin navigation (D10)', () {
    test('layout by width', () {
      expect(AdminNavLayout.forWidth(320), AdminNavLayout.drawer);
      expect(AdminNavLayout.forWidth(375), AdminNavLayout.drawer);
      expect(AdminNavLayout.forWidth(599), AdminNavLayout.drawer);
      expect(AdminNavLayout.forWidth(768), AdminNavLayout.collapsedRail);
      expect(AdminNavLayout.forWidth(1280), AdminNavLayout.expandedRail);
    });

    test('phone drawer leaves room for content (was the 304 dp default)', () {
      expect(AdminNavLayout.drawerWidth(375), 256);
      expect(AdminNavLayout.drawerWidth(320), 240);
      expect(375 - AdminNavLayout.drawerWidth(375), greaterThanOrEqualTo(110));
    });

    Future<void> pumpMenu(WidgetTester tester, {required double width, required bool collapsed, double textScale = 1.0}) async {
      tester.view.physicalSize = Size(width * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final menuWidth = collapsed ? AdminNavLayout.railWidth : (width < 600 ? AdminNavLayout.drawerWidth(width) : AdminNavLayout.expandedWidth);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Row(children: [
              SizedBox(
                width: menuWidth,
                child: AdminNavMenu(
                  current: AdminModule.bookings,
                  collapsed: collapsed,
                  username: 'hoteladmin',
                  email: 'admin.with.a.very.long.email@pethotel.example.com',
                  onSelect: (_) {},
                  onSignOut: () {},
                  onToggleCollapse: width >= 600 ? () {} : null,
                ),
              ),
              const Expanded(child: SizedBox()),
            ]),
          ),
        ),
      ));
      await tester.pump();
    }

    const labels = ['Dashboard', 'Bookings', 'Rooms & Room Types', 'Pets', 'Add-on Services', 'Payments', 'Reviews', 'QR Scanner', 'Sign out'];

    for (final w in [320.0, 375.0]) {
      testWidgets('compact drawer at ${w.toInt()} dp: all items, no overflow (1.0x and 1.3x text)', (tester) async {
        for (final scale in [1.0, 1.3]) {
          await pumpMenu(tester, width: w, collapsed: false, textScale: scale);
          for (final l in labels) {
            expect(find.text(l), findsOneWidget, reason: '$l at ${w}dp ${scale}x');
          }
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('collapsed 72 dp rail at 768 dp: icons with tooltips, no overflow', (tester) async {
      await pumpMenu(tester, width: 768, collapsed: true, textScale: 1.3);
      expect(find.byType(Tooltip), findsNWidgets(labels.length + 2)); // + avatar + expand button
      for (final l in labels) {
        expect(find.byTooltip(l), findsOneWidget);
      }
      expect(find.byTooltip('Expand menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded 240 dp panel at 1280 dp shows labels and collapse toggle', (tester) async {
      await pumpMenu(tester, width: 1280, collapsed: false);
      for (final l in labels) {
        expect(find.text(l), findsOneWidget);
      }
      expect(find.byTooltip('Collapse menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting an item reports its destination', (tester) async {
      tester.view.physicalSize = const Size(750, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      AdminModule? picked;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 256,
            child: AdminNavMenu(current: AdminModule.dashboard, onSelect: (m) => picked = m, onSignOut: () {}),
          ),
        ),
      ));
      await tester.tap(find.text('Payments'));
      expect(picked, AdminModule.payments);
    });
  });

  group('Defect #4: camera screen fallback', () {
    testWidgets('when no camera is available it explains why and offers "Choose a file instead"', (tester) async {
      CameraCaptureResult? result;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CameraCaptureResult>(MaterialPageRoute(builder: (_) => const CameraCaptureScreen()));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      // In the test environment no camera answers: after the startup limit the
      // screen must show the fallback instead of spinning forever.
      // (It may also fail immediately, depending on how the plugin reports it.)
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('Choose a file instead'), findsOneWidget);
      expect(find.text('Try camera again'), findsOneWidget);
      await tester.tap(find.text('Choose a file instead'));
      await tester.pumpAndSettle();
      expect(result?.useFileInstead, isTrue);
    });
  });
}
