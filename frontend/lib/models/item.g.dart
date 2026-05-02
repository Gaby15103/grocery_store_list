// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GroceryItemAdapter extends TypeAdapter<GroceryItem> {
  @override
  final int typeId = 1;

  @override
  GroceryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroceryItem(
      name: fields[0] as String,
      status: fields[1] as ItemStatus,
      createdAt: fields[2] as DateTime,
      listId: fields[3] as String,
      groupId: fields[4] as String,
      addedBy: fields[5] as String?,
      modifiedBy: fields[6] as String?,
      note: fields[7] as String?,
      imagePath: fields[8] as String?,
      id: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, GroceryItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.listId)
      ..writeByte(4)
      ..write(obj.groupId)
      ..writeByte(5)
      ..write(obj.addedBy)
      ..writeByte(6)
      ..write(obj.modifiedBy)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.imagePath)
      ..writeByte(9)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemStatusAdapter extends TypeAdapter<ItemStatus> {
  @override
  final int typeId = 0;

  @override
  ItemStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemStatus.pending;
      case 1:
        return ItemStatus.bought;
      case 2:
        return ItemStatus.discarded;
      default:
        return ItemStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ItemStatus obj) {
    switch (obj) {
      case ItemStatus.pending:
        writer.writeByte(0);
        break;
      case ItemStatus.bought:
        writer.writeByte(1);
        break;
      case ItemStatus.discarded:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
