// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DataModelAdapter extends TypeAdapter<DataModel> {
  @override
  final typeId = 2;

  @override
  DataModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      userName: fields[2] as String,
      title: fields[3] as String,
      description: fields[4] as String,
      submittedAt: fields[5] as DateTime,
      status: fields[6] == null ? DataStatus.pending : fields[6] as DataStatus,
      verifiedAt: fields[7] as DateTime?,
      verifiedBy: fields[8] as String?,
      rejectionReason: fields[9] as String?,
      isFavorite: fields[10] == null ? false : fields[10] as bool,
      attachments: fields[11] == null
          ? const []
          : (fields[11] as List).cast<String>(),
      letterNumber: fields[12] as String?,
      isLetterRequest: fields[13] == null ? false : fields[13] as bool,
      applicantDetails: fields[14] == null
          ? const {}
          : (fields[14] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DataModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.submittedAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.verifiedAt)
      ..writeByte(8)
      ..write(obj.verifiedBy)
      ..writeByte(9)
      ..write(obj.rejectionReason)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.attachments)
      ..writeByte(12)
      ..write(obj.letterNumber)
      ..writeByte(13)
      ..write(obj.isLetterRequest)
      ..writeByte(14)
      ..write(obj.applicantDetails);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
