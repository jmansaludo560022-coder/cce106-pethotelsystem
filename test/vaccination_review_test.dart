import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/pets_list_screen.dart';
import 'package:flutter_pethotelbooking/models/pet_model.dart';

/// The admin reviews the vaccination file a customer uploaded: Pending,
/// Validated or Rejected (with a reason).
void main() {
  PetModel pet({String file = 'https://x/vaccination.pdf', String status = VaccinationStatus.pending, String note = ''}) => PetModel(
        petID: 'p1',
        cusID: 'c1',
        petName: 'Mochi',
        petType: 'Dog',
        breed: 'Shih Tzu',
        gender: 'Female',
        weightSize: 'Small (S)',
        vaccinationFile: file,
        vaccinationStatus: status,
        vaccinationNote: note,
      );

  group('Vaccination review state', () {
    test('a new upload waits for review; no file means no review', () {
      expect(pet().needsVaccinationReview, isTrue);
      expect(pet().vaccinationBadgeLabel, 'FOR REVIEW');
      expect(pet(file: '').needsVaccinationReview, isFalse);
      expect(pet(file: '').vaccinationBadgeLabel, 'NO VACC. FILE');
    });

    test('validated and rejected records show their own badge', () {
      expect(pet(status: VaccinationStatus.validated).vaccinationBadgeLabel, 'VALIDATED');
      expect(pet(status: VaccinationStatus.validated).vaccinationBadgeStatus, 'approved');
      expect(pet(status: VaccinationStatus.rejected).vaccinationBadgeLabel, 'REJECTED');
      expect(pet(status: VaccinationStatus.rejected).vaccinationBadgeStatus, 'rejected');
    });

    test('older pets without a status are treated as Pending, and unknown values too', () {
      expect(VaccinationStatus.normalize(null), VaccinationStatus.pending);
      expect(VaccinationStatus.normalize('whatever'), VaccinationStatus.pending);
      expect(VaccinationStatus.normalize('validated'), VaccinationStatus.validated);
    });

    test('only a validated pet can be booked by a customer, and the reason is explained', () {
      expect(pet(status: VaccinationStatus.validated).bookingBlockReason, isNull);
      expect(pet().bookingBlockReason, contains('waiting for the hotel'));
      expect(pet(file: '').bookingBlockReason, contains('no vaccination file'));
      expect(pet(status: VaccinationStatus.rejected, note: 'Blurred').bookingBlockReason, allOf(contains('rejected'), contains('Blurred')));
    });

    test('the review is saved with the pet', () {
      final m = pet(status: VaccinationStatus.rejected, note: 'Blurred').toMap();
      expect(m['vaccinationStatus'], 'Rejected');
      expect(m['vaccinationNote'], 'Blurred');
      expect(m['vaccinationReviewedAt'], isNull);
    });
  });

  testWidgets('Customer pet card shows the review status and the rejection reason', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            PetCard(pet: pet(status: VaccinationStatus.validated)),
            PetCard(pet: pet(status: VaccinationStatus.rejected, note: 'Dates are cut off')),
          ]),
        ),
      ),
    ));
    expect(find.text('VALIDATED'), findsOneWidget);
    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.textContaining('Dates are cut off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
