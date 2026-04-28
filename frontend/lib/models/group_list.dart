import 'package:hive/hive.dart';

part 'group_list.g.dart';

@HiveType(typeId: 3)
class GroceryList extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String groupId;
  @HiveField(3) DateTime createdAt;
  @HiveField(4) bool isArchived;

  GroceryList({
    required this.id,
    required this.name,
    required this.groupId,
    required this.createdAt,
    this.isArchived = false,
  });

  factory GroceryList.fromJson(Map<String, dynamic> json) {
    return GroceryList(
      id: json['id'] as String,
      name: json['name'] as String,
      groupId: json['group_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isArchived: json['is_archived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group_id': groupId,
      'created_at': createdAt.toIso8601String(),
      'is_archived': isArchived,
    };
  }
}