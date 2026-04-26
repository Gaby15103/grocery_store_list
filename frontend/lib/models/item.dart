import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
enum ItemStatus {
  @HiveField(0) pending,
  @HiveField(1) bought,
  @HiveField(2) discarded
}

@HiveType(typeId: 1)
class GroceryItem extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) ItemStatus status;
  @HiveField(2) DateTime createdAt;
  @HiveField(3) String listId;   // The specific "Trip" ID
  @HiveField(4) String groupId;  // The owner (Personal, Family, etc.)

  @HiveField(5) String? addedBy;    // User ID/Name who created it
  @HiveField(6) String? modifiedBy; // User ID/Name who last changed status

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name, // pending, bought, etc.
    'createdAt': createdAt.toIso8601String(),
    'listId': listId,
    'groupId': groupId,
  };

  GroceryItem({
    required this.name,
    this.status = ItemStatus.pending,
    required this.createdAt,
    required this.listId,
    required this.groupId,
    this.addedBy,
    this.modifiedBy,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: json['name'],
      listId: json['ListId'] ?? json['listId'],
      groupId: json['groupId'] ?? '',
      status: _statusFromString(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static ItemStatus _statusFromString(String status) {
    switch (status) {
      case 'bought': return ItemStatus.bought;
      case 'discarded': return ItemStatus.discarded;
      default: return ItemStatus.pending;
    }
  }
}