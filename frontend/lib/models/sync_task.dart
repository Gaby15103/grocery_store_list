import 'package:hive/hive.dart';

part 'sync_task.g.dart';

@HiveType(typeId: 5) // Use a new ID
class SyncTask extends HiveObject {
  @HiveField(0)
  final String method; // 'POST', 'PUT', 'DELETE'
  @HiveField(1)
  final String path;
  @HiveField(2)
  final Map<String, dynamic>? body;
  @HiveField(3)
  final DateTime timestamp;

  SyncTask({
    required this.method,
    required this.path,
    this.body,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();
}