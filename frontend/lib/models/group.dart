import 'package:hive/hive.dart';

part 'group.g.dart';

@HiveType(typeId: 2)
class GroceryGroup extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) bool isShared;

  GroceryGroup({
    required this.id,
    required this.name,
    this.isShared = false,
  });
}