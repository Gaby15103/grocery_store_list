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
}