// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'psv_badge_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PsvBadgeData _$PsvBadgeDataFromJson(Map<String, dynamic> json) => PsvBadgeData(
      badgeNumber: json['badge_number'] as String,
      driverName: json['driver_name'] as String? ?? '',
      vehicleClass: json['vehicle_class'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      issueDate: json['issue_date'] as String? ?? '',
    );

Map<String, dynamic> _$PsvBadgeDataToJson(PsvBadgeData instance) =>
    <String, dynamic>{
      'badge_number': instance.badgeNumber,
      'driver_name': instance.driverName,
      'vehicle_class': instance.vehicleClass,
      'expiry_date': instance.expiryDate,
      'issue_date': instance.issueDate,
    };
