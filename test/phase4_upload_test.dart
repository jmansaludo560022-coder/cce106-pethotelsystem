import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/utils/upload_rules.dart';
import 'package:flutter_pethotelbooking/core/widgets/widgets.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/pet_registration.dart';

/// Phase 4 — vaccination records as image or PDF (decision D5), with
/// type/size validation and a distinct "Upload file" action.
void main() {
  Uint8List bytes(List<int> head, [int total = 64]) => Uint8List(total)..setRange(0, head.length, head);
  final pdf = bytes('%PDF-1.7'.codeUnits);
  final jpg = bytes([0xFF, 0xD8, 0xFF, 0xE0]);
  final png = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final webp = bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]);
  final heic = bytes([0, 0, 0, 0x18, ...'ftypheic'.codeUnits]);

  group('Upload rules', () {
    test('detects type from the file signature', () {
      expect(UploadRules.check(pdf, 'card.pdf').isPdf, isTrue);
      expect(UploadRules.check(pdf, 'card.pdf').contentType, 'application/pdf');
      expect(UploadRules.check(jpg, 'a.jpg').contentType, 'image/jpeg');
      expect(UploadRules.check(png, 'a.png').contentType, 'image/png');
      expect(UploadRules.check(webp, 'a.webp').contentType, 'image/webp');
      expect(UploadRules.check(heic, 'a.heic').contentType, 'image/heic');
    });

    test('a renamed non-image / non-PDF file is rejected', () {
      final exe = bytes('MZ'.codeUnits);
      expect(() => UploadRules.check(exe, 'certificate.pdf'), throwsA(isA<UploadRuleException>().having((e) => e.message, 'message', UploadRules.typeError)));
      expect(() => UploadRules.check(bytes('hello'.codeUnits), 'note.jpg'), throwsA(isA<UploadRuleException>()));
    });

    test('photo-only paths refuse PDFs', () {
      expect(() => UploadRules.check(pdf, 'x.pdf', allowPdf: false),
          throwsA(isA<UploadRuleException>().having((e) => e.message, 'message', UploadRules.imageOnlyError)));
    });

    test('5 MB limit and empty files', () {
      final big = bytes('%PDF-'.codeUnits, UploadRules.maxBytes + 1);
      expect(() => UploadRules.check(big, 'big.pdf'), throwsA(isA<UploadRuleException>().having((e) => e.message, 'message', contains('5 MB'))));
      expect(UploadRules.check(bytes('%PDF-'.codeUnits, UploadRules.maxBytes), 'ok.pdf').size, UploadRules.maxBytes);
      expect(() => UploadRules.check(Uint8List(0), 'empty.pdf'), throwsA(isA<UploadRuleException>()));
    });

    test('recognises stored PDF download URLs (encoded Firebase paths)', () {
      const pdfUrl = 'https://firebasestorage.googleapis.com/v0/b/x.app/o/pets%2Fc1%2Fp1%2Fvaccination.pdf?alt=media&token=t';
      const jpgUrl = 'https://firebasestorage.googleapis.com/v0/b/x.app/o/pets%2Fc1%2Fp1%2Fvaccination.jpg?alt=media&token=t';
      expect(UploadRules.isPdfUrl(pdfUrl), isTrue);
      expect(UploadRules.isPdfUrl(jpgUrl), isFalse);
      expect(UploadRules.isPdfUrl(''), isFalse);
    });
  });

  group('Vaccination record UI', () {
    final theme = AppTheme.lightTheme();
    tearDown(() => DocumentPicker.debugOverride = null);

    testWidgets('sheet offers three distinct actions', (tester) async {
      DocumentSource? chosen;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => chosen = await showModalBottomSheet<DocumentSource>(context: context, builder: (_) => const DocumentSourceOptions(title: 'Vaccination record')),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Upload file'), findsOneWidget);
      expect(find.text('PDF or image, up to 5 MB'), findsOneWidget);
      await tester.tap(find.text('Upload file'));
      await tester.pumpAndSettle();
      expect(chosen, DocumentSource.file);
    });

    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme, home: const PetFormScreen(cusID: 'c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add vaccination record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload file'));
      await tester.pumpAndSettle();
    }

    testWidgets('uploading a PDF shows the PDF indicator with name and size', (tester) async {
      DocumentPicker.debugOverride = () async => (bytes('%PDF-'.codeUnits, 2048), 'rabies-certificate.pdf');
      await openForm(tester);
      expect(find.byType(VaccinationFileTile), findsOneWidget);
      expect(find.text('rabies-certificate.pdf'), findsOneWidget);
      expect(find.text('PDF document · 2 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing, reason: 'no image preview for a PDF');

      // Remove, then the empty upload card is back.
      await tester.tap(find.byTooltip('Remove file'));
      await tester.pumpAndSettle();
      expect(find.text('Add vaccination record'), findsOneWidget);
    });

    testWidgets('a file over 5 MB is refused with a clear message', (tester) async {
      DocumentPicker.debugOverride = () async => throw UploadRuleException(UploadRules.sizeError(6 * 1024 * 1024));
      await openForm(tester);
      expect(find.textContaining('The limit is 5 MB'), findsOneWidget);
      expect(find.byType(VaccinationFileTile), findsNothing);
    });

    testWidgets('a wrong file type is refused', (tester) async {
      DocumentPicker.debugOverride = () async => (bytes('PK'.codeUnits), 'records.pdf'); // a ZIP renamed to .pdf
      await openForm(tester);
      expect(find.text(UploadRules.typeError), findsOneWidget);
      expect(find.byType(VaccinationFileTile), findsNothing);
    });

    testWidgets('cancelling the file chooser changes nothing', (tester) async {
      DocumentPicker.debugOverride = () async => null;
      await openForm(tester);
      expect(find.text('Add vaccination record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pet form fits a 320 dp phone at 1.3x text (long breed names)', (tester) async {
      tester.view.physicalSize = const Size(640, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 2000), textScaler: TextScaler.linear(1.3)),
          child: const PetFormScreen(cusID: 'c1'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Basic info'), findsOneWidget);
      expect(find.text('Vaccination record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saved PDF record shows "PDF on file"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: VaccinationFileTile(
            existingUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/pets%2Fc%2Fp%2Fvaccination.pdf?alt=media',
            onTogglePreview: () {},
            onRemove: () {},
            onReplace: () {},
          ),
        ),
      ));
      expect(find.text('PDF on file'), findsOneWidget);
      expect(find.byTooltip('Show preview'), findsNothing);
      expect(find.byTooltip('Hide preview'), findsNothing);
    });
  });
}
