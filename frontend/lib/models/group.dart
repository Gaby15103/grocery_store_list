import 'package:hive/hive.dart';

part 'group.g.dart';

@HiveType(typeId: 2)
class GroceryGroup extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  bool isShared;

  GroceryGroup({required this.id, required this.name, this.isShared = false});

  factory GroceryGroup.fromJson(Map<String, dynamic> json) {
    return GroceryGroup(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Group',
      isShared: json['isShared'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'isShared': isShared};
  }
}
