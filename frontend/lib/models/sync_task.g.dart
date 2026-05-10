// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncTaskAdapter extends TypeAdapter<SyncTask> {
  @override
  final int typeId = 5;

  @override
  SyncTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncTask(
      method: fields[0] as String,
      path: fields[1] as String,
      body: (fields[2] as Map?)?.cast<String, dynamic>(),
      timestamp: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncTask obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.method)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
