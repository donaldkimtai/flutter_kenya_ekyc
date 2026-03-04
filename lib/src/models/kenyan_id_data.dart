import 'package:json_annotation/json_annotation.dart';

part 'kenyan_id_data.g.dart';

/// Extracted data from a Kenyan National ID or Driving Licence front face.
@JsonSerializable(fieldRename: FieldRename.snake)
class KenyanIdData {
  /// The unique 7 or 8 digit ID number.
  final String idNumber;

  /// The full name of the citizen as printed on the document.
  final String fullName;

  /// Date of birth extracted from the document (DD.MM.YYYY or DD/MM/YYYY).
  final String dateOfBirth;

  /// Gender as printed: "MALE" or "FEMALE". Empty if not extracted.
  final String gender;

  /// District or county of birth/registration. Empty if not extracted.
  final String district;

  /// Document expiry date (relevant for driving licences). Empty if not applicable.
  final String expiryDate;

  const KenyanIdData({
    required this.idNumber,
    required this.fullName,
    required this.dateOfBirth,
    this.gender = '',
    this.district = '',
    this.expiryDate = '',
  });

  factory KenyanIdData.fromJson(Map<String, dynamic> json) =>
      _$KenyanIdDataFromJson(json);

  Map<String, dynamic> toJson() => _$KenyanIdDataToJson(this);
}