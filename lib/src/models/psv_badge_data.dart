import 'package:json_annotation/json_annotation.dart';

part 'psv_badge_data.g.dart';

/// Extracted data from a Kenyan PSV (Public Service Vehicle) Badge.
@JsonSerializable(fieldRename: FieldRename.snake)
class PsvBadgeData {
  /// The unique PSV badge number issued by NTSA.
  final String badgeNumber;

  /// Full name of the licensed PSV driver.
  final String driverName;

  /// Permitted vehicle class (e.g., Matatu, Bus, Taxi).
  final String vehicleClass;

  /// Badge expiry date (DD.MM.YYYY or DD/MM/YYYY).
  final String expiryDate;

  /// Badge issue date (DD.MM.YYYY or DD/MM/YYYY).
  final String issueDate;

  const PsvBadgeData({
    required this.badgeNumber,
    this.driverName = '',
    this.vehicleClass = '',
    this.expiryDate = '',
    this.issueDate = '',
  });

  factory PsvBadgeData.fromJson(Map<String, dynamic> json) =>
      _$PsvBadgeDataFromJson(json);

  Map<String, dynamic> toJson() => _$PsvBadgeDataToJson(this);
}