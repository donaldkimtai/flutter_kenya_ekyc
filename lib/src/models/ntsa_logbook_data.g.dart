// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ntsa_logbook_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NtsaLogbookData _$NtsaLogbookDataFromJson(Map<String, dynamic> json) =>
    NtsaLogbookData(
      plateNumber: json['plate_number'] as String,
      chassisNumber: json['chassis_number'] as String,
      ownerName: json['owner_name'] as String,
      vehicleMake: json['vehicle_make'] as String? ?? '',
      vehicleModel: json['vehicle_model'] as String? ?? '',
      yearOfManufacture: json['year_of_manufacture'] as String? ?? '',
      engineNumber: json['engine_number'] as String? ?? '',
    );

Map<String, dynamic> _$NtsaLogbookDataToJson(NtsaLogbookData instance) =>
    <String, dynamic>{
      'plate_number': instance.plateNumber,
      'chassis_number': instance.chassisNumber,
      'owner_name': instance.ownerName,
      'vehicle_make': instance.vehicleMake,
      'vehicle_model': instance.vehicleModel,
      'year_of_manufacture': instance.yearOfManufacture,
      'engine_number': instance.engineNumber,
    };
