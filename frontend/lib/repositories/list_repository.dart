import 'package:hive/hive.dart';
import '../models/group_list.dart';
import '../models/item.dart';
import '../services/api/list_api_client.dart';

class ListRepository {
  final ListApiClient _apiClient;
  final Box<GroceryList> _listBox = Hive.box<GroceryList>('lists');
  final Box<GroceryItem> _itemBox = Hive.box<GroceryItem>('items');

  ListRepository(this._apiClient);

  /// 1. Get lists from Server and update local cache
  Future<List<GroceryList>> getLists(String groupId, bool isShared) async {
    if (isShared) {
      try {
        final remoteLists = await _apiClient.fetchLists(groupId);

        final localKeys = _listBox.values.where((l) => l.groupId == groupId).map((e) => e.id);
        for (var key in localKeys) await _listBox.delete(key);

        for (var list in remoteLists) await _listBox.put(list.id, list);

        return remoteLists;
      } catch (e) {
        return _listBox.values.where((l) => l.groupId == groupId).toList();
      }
    }
    return _listBox.values.where((l) => l.groupId == groupId).toList();
  }

  /// 2. Create a new List
  Future<GroceryList> addList(String name, String groupId, bool isShared) async {
    if (isShared) {
      final newList = await _apiClient.createList(name, groupId);
      await _listBox.put(newList.id, newList);
      return newList;
    } else {
      final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
      final newList = GroceryList(id: id, name: name, groupId: groupId, createdAt: DateTime.now());
      await _listBox.put(id, newList);
      return newList;
    }
  }

  /// 3. Delete List and orphaned Items
  Future<void> removeList(String listId, bool isShared) async {
    if (isShared) await _apiClient.deleteList(listId);

    await _listBox.delete(listId);

    final itemKeys = _itemBox.values.where((i) => i.listId == listId).map((e) => e.id);
    for (var key in itemKeys) await _itemBox.delete(key);
  }

  Future<GroceryList> archiveAndCarryOver(String listId, String newName, String groupId, bool isShared) async {
    if (isShared) {
      final newList = await _apiClient.archiveList(listId, newName);

      final oldList = _listBox.get(listId);
      if (oldList != null) {
        oldList.isArchived = true;
        await oldList.save();
      }

      await _listBox.put(newList.id, newList);

      final pendingItems = _itemBox.values.where((i) => i.listId == listId && i.status == ItemStatus.pending);
      for (var item in pendingItems) {
        item.listId = newList.id;
        await item.save();
      }

      return newList;
    } else {
      final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
      final newList = GroceryList(id: id, name: "Liste (Cont.)", groupId: groupId, createdAt: DateTime.now());
      await _listBox.put(id, newList);
      return newList;
    }
  }
}