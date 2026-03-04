import 'package:json_annotation/json_annotation.dart';

part 'driving_license_data.g.dart';

/// Extracted data from a Kenyan Driving Licence.
@JsonSerializable(fieldRename: FieldRename.snake)
class DrivingLicenseData {
  /// Driving licence number (e.g., DL0012345).
  final String licenceNumber;

  /// Full name of the licence holder.
  final String holderName;

  /// Date of birth (DD.MM.YYYY or DD/MM/YYYY).
  final String dateOfBirth;

  /// Date the licence was issued.
  final String issueDate;

  /// Licence expiry date.
  final String expiryDate;

  /// Permitted vehicle classes (e.g., ["A", "B", "C"]).
  final List<String> vehicleClasses;

  const DrivingLicenseData({
    required this.licenceNumber,
    this.holderName = '',
    this.dateOfBirth = '',
    this.issueDate = '',
    this.expiryDate = '',
    this.vehicleClasses = const [],
  });

  factory DrivingLicenseData.fromJson(Map<String, dynamic> json) =>
      _$DrivingLicenseDataFromJson(json);

  Map<String, dynamic> toJson() => _$DrivingLicenseDataToJson(this);
}