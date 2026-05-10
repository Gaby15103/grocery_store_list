import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../models/sync_task.dart';
import 'api/base_api.dart';

class SyncManager {
  final Box<SyncTask> _queueBox = Hive.box<SyncTask>('sync_queue');
  bool _isProcessing = false;

  void enqueue(String method, String path, dynamic body) {
    final task = SyncTask(method: method, path: path, body: body as Map<String, dynamic>?);
    _queueBox.add(task);
  }

  Future<void> processQueue(BaseApi api) async {
    if (_isProcessing || _queueBox.isEmpty) return;
    _isProcessing = true;

    final keys = _queueBox.keys.toList();
    for (var key in keys) {
      final task = _queueBox.get(key);
      if (task == null) continue;

      try {
        await api.request(
          method: task.method,
          path: task.path,
          body: task.body,
          fromJson: (json) => json,
        );
        await _queueBox.delete(key);
      } catch (e) {
        debugPrint("Replay failed for ${task.path}: $e");
        break;
      }
    }
    _isProcessing = false;
  }
}