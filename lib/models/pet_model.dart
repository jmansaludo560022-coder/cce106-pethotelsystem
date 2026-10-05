import 'package:cloud_firestore/cloud_firestore.dart';

/// Review state of a pet's vaccination record. The customer uploads the file;
/// only the admin can set it to [validated] or [rejected]. A new upload always
/// goes back to [pending].
class VaccinationStatus {
  static const pending = 'Pending';
  static const validated = 'Validated';
  static const rejected = 'Rejected';

  static String normalize(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'validated':
        return validated;
      case 'rejected':
        return rejected;
      default:
        return pending;
    }
  }
}

class PetModel {
  final String petID;
  final String cusID;
  final String petName;
  final String petPhoto;
  final String petType; // 'Dog', 'Cat', etc.
  final String breed;
  final String gender; // 'Male', 'Female'
  final DateTime? birthdate;
  final String
  weightSize; // 'Small (S)', 'Medium (M)', 'Large (L)', 'Giant (XL)'
  final String vaccinationFile; // Firebase Storage download URL
  final String vaccinationStatus; // VaccinationStatus.*
  final String vaccinationNote; // reason shown to the customer when rejected
  final DateTime? vaccinationReviewedAt;
  final DateTime createdAt;

  PetModel({
    required this.petID,
    required this.cusID,
    required this.petName,
    this.petPhoto = '',
    required this.petType,
    required this.breed,
    required this.gender,
    this.birthdate,
    required this.weightSize,
    this.vaccinationFile = '',
    this.vaccinationStatus = VaccinationStatus.pending,
    this.vaccinationNote = '',
    this.vaccinationReviewedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasVaccinationRecord => vaccinationFile.isNotEmpty;
  bool get isVaccinationValidated => hasVaccinationRecord && vaccinationStatus == VaccinationStatus.validated;
  bool get isVaccinationRejected => hasVaccinationRecord && vaccinationStatus == VaccinationStatus.rejected;
  bool get needsVaccinationReview => hasVaccinationRecord && vaccinationStatus == VaccinationStatus.pending;

  /// Customers can book only pets whose vaccination file the admin validated.
  /// Returns the message to show when the pet cannot be booked, or null when it can.
  String? get bookingBlockReason {
    if (isVaccinationValidated) return null;
    if (!hasVaccinationRecord) return "$petName has no vaccination file yet. Add one in My Pets.";
    if (isVaccinationRejected) {
      final why = vaccinationNote.isEmpty ? '' : ': $vaccinationNote';
      return "The hotel rejected $petName's vaccination file$why. Upload a new file in My Pets.";
    }
    return "$petName's vaccination file is waiting for the hotel to validate it.";
  }

  /// Badge text and the [StatusBadge] colour key for the vaccination record.
  String get vaccinationBadgeLabel {
    if (!hasVaccinationRecord) return 'NO VACC. FILE';
    if (isVaccinationValidated) return 'VALIDATED';
    if (isVaccinationRejected) return 'REJECTED';
    return 'FOR REVIEW';
  }

  String get vaccinationBadgeStatus {
    if (isVaccinationValidated) return 'approved';
    if (isVaccinationRejected) return 'rejected';
    return 'pending';
  }

  /// e.g. "Medium (M)" → "Medium".
  String get sizeLabel => weightSize.split(' (').first;

  String get subtitle => [breed, if (gender.isNotEmpty) gender].join(' · ');

  factory PetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PetModel(
      petID: doc.id,
      cusID: data['cusID'] ?? '',
      petName: data['petName'] ?? '',
      petPhoto: data['petPhoto'] ?? '',
      petType: data['petType'] ?? 'Dog',
      breed: data['breed'] ?? '',
      gender: data['gender'] ?? 'Male',
      birthdate: (data['birthdate'] as Timestamp?)?.toDate(),
      weightSize: data['weightSize'] ?? 'Small',
      vaccinationFile: data['vaccinationFile'] ?? '',
      vaccinationStatus: VaccinationStatus.normalize(data['vaccinationStatus'] as String?),
      vaccinationNote: data['vaccinationNote'] ?? '',
      vaccinationReviewedAt: (data['vaccinationReviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'petID': petID,
      'cusID': cusID,
      'petName': petName,
      'petPhoto': petPhoto,
      'petType': petType,
      'breed': breed,
      'gender': gender,
      'birthdate': birthdate != null ? Timestamp.fromDate(birthdate!) : null,
      'weightSize': weightSize,
      'vaccinationFile': vaccinationFile,
      'vaccinationStatus': vaccinationStatus,
      'vaccinationNote': vaccinationNote,
      'vaccinationReviewedAt': vaccinationReviewedAt != null ? Timestamp.fromDate(vaccinationReviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  PetModel copyWith({
    String? petID,
    String? cusID,
    String? petName,
    String? petPhoto,
    String? petType,
    String? breed,
    String? gender,
    DateTime? birthdate,
    String? weightSize,
    String? vaccinationFile,
    String? vaccinationStatus,
    String? vaccinationNote,
    DateTime? vaccinationReviewedAt,
    bool clearReview = false,
    DateTime? createdAt,
  }) {
    return PetModel(
      petID: petID ?? this.petID,
      cusID: cusID ?? this.cusID,
      petName: petName ?? this.petName,
      petPhoto: petPhoto ?? this.petPhoto,
      petType: petType ?? this.petType,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      weightSize: weightSize ?? this.weightSize,
      vaccinationFile: vaccinationFile ?? this.vaccinationFile,
      vaccinationStatus: vaccinationStatus ?? this.vaccinationStatus,
      vaccinationNote: vaccinationNote ?? this.vaccinationNote,
      vaccinationReviewedAt: clearReview ? null : (vaccinationReviewedAt ?? this.vaccinationReviewedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
