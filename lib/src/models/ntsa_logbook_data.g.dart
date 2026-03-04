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
    );

Map<String, dynamic> _$NtsaLogbookDataToJson(NtsaLogbookData instance) =>
    <String, dynamic>{
      'plate_number': instance.plateNumber,
      'chassis_number': instance.chassisNumber,
      'owner_name': instance.ownerName,
    };
