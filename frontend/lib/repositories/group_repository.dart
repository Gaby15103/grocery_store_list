import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/group.dart';
import '../services/api/group_api_client.dart';

class GroupRepository {
  final GroupApiClient _apiClient;
  final Box<GroceryGroup> _groupBox = Hive.box<GroceryGroup>('groups');
  final Box<String> _metaBox = Hive.box<String>('metadata');

  GroupRepository(this._apiClient);

  List<GroceryGroup> getCachedGroups() => _groupBox.values.toList();

  Future<List<GroceryGroup>> refreshGroups() async {
    try {
      final remoteGroups = await _apiClient.fetchGroups();

      await _groupBox.clear();
      for (var group in remoteGroups) {
        await _groupBox.put(group.id, group);
      }
      return remoteGroups;
    } catch (e) {
      debugPrint("Repository: Sync failed, using local data. $e");
      return getCachedGroups();
    }
  }

  Future<void> makeGroupPublic(String groupId) async {
    final updatedGroup = await _apiClient.makeGroupPublic(groupId);
    await _groupBox.put(groupId, updatedGroup);
  }

  /// 3. Create Group
  Future<void> createGroup(String name) async {
    final serverGroup = await _apiClient.createGroup(name);
    if (serverGroup != null) {
      await _groupBox.put(serverGroup.id, serverGroup);
    }
  }

  /// 4. Delete Group
  Future<void> removeGroup(String groupId) async {
    await _apiClient.deleteGroup(groupId);
    await _groupBox.delete(groupId);

    if (getActiveGroupId() == groupId) {
      await _metaBox.put('activeGroupId', 'default');
    }
  }

  /// 5. Active Group State (Persisted in Metadata)
  String getActiveGroupId() => _metaBox.get('activeGroupId') ?? 'default';

  Future<void> saveActiveGroupId(String id) async {
    await _metaBox.put('activeGroupId', id);
  }
}