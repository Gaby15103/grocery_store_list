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
  @HiveField(3) String listId;
  @HiveField(4) String groupId;

  @HiveField(5) String? addedBy;
  @HiveField(6) String? modifiedBy;

  // --- NEW FIELDS ---
  @HiveField(7) String? note;      // For the item note
  @HiveField(8) String? imagePath; // For the server-side image path

  GroceryItem({
    required this.name,
    this.status = ItemStatus.pending,
    required this.createdAt,
    required this.listId,
    required this.groupId,
    this.addedBy,
    this.modifiedBy,
    this.note,       // Added
    this.imagePath,  // Added
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'listId': listId,
    'groupId': groupId,
    'note': note,           // Added to JSON
    'imagePath': imagePath, // Added to JSON
  };

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: json['name'],
      listId: json['ListId'] ?? json['listId'],
      groupId: json['groupId'] ?? '',
      status: _statusFromString(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      note: json['note'],           // Added from JSON
      imagePath: json['imagePath'], // Added from JSON
      addedBy: json['addedBy'],
      modifiedBy: json['modifiedBy'],
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