import 'package:json_annotation/json_annotation.dart';

part 'ntsa_logbook_data.g.dart';

/// Extracted data from an NTSA Vehicle Logbook.
@JsonSerializable(fieldRename: FieldRename.snake)
class NtsaLogbookData {
  /// Vehicle registration plate number (e.g., KBC 123J).
  final String plateNumber;

  /// Chassis / frame number (17-char VIN or shorter local format).
  final String chassisNumber;

  /// Registered owner's full name.
  final String ownerName;

  /// Vehicle make / manufacturer (e.g., TOYOTA, NISSAN).
  final String vehicleMake;

  /// Vehicle model (e.g., HIACE, MATATU).
  final String vehicleModel;

  /// Year of manufacture (e.g., 2018).
  final String yearOfManufacture;

  /// Engine number.
  final String engineNumber;

  const NtsaLogbookData({
    required this.plateNumber,
    required this.chassisNumber,
    required this.ownerName,
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.yearOfManufacture = '',
    this.engineNumber = '',
  });

  factory NtsaLogbookData.fromJson(Map<String, dynamic> json) =>
      _$NtsaLogbookDataFromJson(json);

  Map<String, dynamic> toJson() => _$NtsaLogbookDataToJson(this);
}