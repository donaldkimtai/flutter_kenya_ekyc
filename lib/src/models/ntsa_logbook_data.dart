import 'package:json_annotation/json_annotation.dart';

part 'ntsa_logbook_data.g.dart';

/// Represents the extracted data from an NTSA Vehicle Logbook.
@JsonSerializable(fieldRename: FieldRename.snake)
class NtsaLogbookData {
  /// The vehicle's registration plate number (e.g., KBC 123J).
  final String plateNumber;

  /// The unique chassis or frame number.
  final String chassisNumber;

  /// The registered owner's name.
  final String ownerName;

  /// Creates a new immutable [NtsaLogbookData] instance.
  const NtsaLogbookData({
    required this.plateNumber,
    required this.chassisNumber,
    required this.ownerName,
  });

  /// Creates an [NtsaLogbookData] from a JSON map.
  factory NtsaLogbookData.fromJson(Map<String, dynamic> json) => 
      _$NtsaLogbookDataFromJson(json);

  /// Converts this [NtsaLogbookData] to a JSON map.
  Map<String, dynamic> toJson() => _$NtsaLogbookDataToJson(this);
}