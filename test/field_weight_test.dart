import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/pet_registration.dart';

/// Spec §3 / §8 and owner request: text inside fields (typed or selected)
/// must be normal weight (400), never bold.
FontWeight _effectiveWeight(WidgetTester tester, Finder f) {
  final element = tester.element(f);
  final w = tester.widget(f);
  if (w is EditableText) return w.style.fontWeight ?? FontWeight.w400; // typed text
  final style = DefaultTextStyle.of(element).style.merge((w as Text).style);
  return style.fontWeight ?? FontWeight.w400;
}

void main() {
  testWidgets('Register a Pet: dropdown and typed values are regular weight', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const PetFormScreen(cusID: 'c1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Buddy');
    await tester.pump();

    for (final value in ['Buddy', 'Dog', 'Aspin', 'Male', 'Medium (M)', 'Not set']) {
      final f = find.text(value).first;
      expect(_effectiveWeight(tester, f), FontWeight.w400, reason: '"$value" should not be bold');
    }
  });
}
