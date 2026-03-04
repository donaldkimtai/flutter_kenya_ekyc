// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driving_license_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DrivingLicenseData _$DrivingLicenseDataFromJson(Map<String, dynamic> json) =>
    DrivingLicenseData(
      licenceNumber: json['licence_number'] as String,
      holderName: json['holder_name'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String? ?? '',
      issueDate: json['issue_date'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      vehicleClasses: (json['vehicle_classes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DrivingLicenseDataToJson(DrivingLicenseData instance) =>
    <String, dynamic>{
      'licence_number': instance.licenceNumber,
      'holder_name': instance.holderName,
      'date_of_birth': instance.dateOfBirth,
      'issue_date': instance.issueDate,
      'expiry_date': instance.expiryDate,
      'vehicle_classes': instance.vehicleClasses,
    };
