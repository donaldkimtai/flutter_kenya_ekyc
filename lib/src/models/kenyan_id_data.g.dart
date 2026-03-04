// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kenyan_id_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KenyanIdData _$KenyanIdDataFromJson(Map<String, dynamic> json) => KenyanIdData(
      idNumber: json['id_number'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] as String,
    );

Map<String, dynamic> _$KenyanIdDataToJson(KenyanIdData instance) =>
    <String, dynamic>{
      'id_number': instance.idNumber,
      'full_name': instance.fullName,
      'date_of_birth': instance.dateOfBirth,
    };
