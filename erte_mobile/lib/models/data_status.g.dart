// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DataStatusAdapter extends TypeAdapter<DataStatus> {
  @override
  final typeId = 0;

  @override
  DataStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DataStatus.pending;
      case 1:
        return DataStatus.approved;
      case 2:
        return DataStatus.rejected;
      case 3:
        return DataStatus.processing;
      case 4:
        return DataStatus.completed;
      default:
        return DataStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, DataStatus obj) {
    switch (obj) {
      case DataStatus.pending:
        writer.writeByte(0);
      case DataStatus.approved:
        writer.writeByte(1);
      case DataStatus.rejected:
        writer.writeByte(2);
      case DataStatus.processing:
        writer.writeByte(3);
      case DataStatus.completed:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
