import 'package:hive/hive.dart';
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';
import '../services/sync_service.dart';

class GroceryRepository {
  final Box<GroceryItem> _itemBox = Hive.box<GroceryItem>('items');
  final Box<GroceryGroup> _groupBox = Hive.box<GroceryGroup>('groups');
  final Box<GroceryList> _listBox = Hive.box<GroceryList>('lists');
  final Box<String> _metaBox = Hive.box<String>('metadata');
  final SyncService _syncService = SyncService();

  // --- HELPER LOGIC ---

  /// Checks if the current active group is marked as shared/server-side
  bool _shouldSync() {
    final activeId = getActiveGroupId();
    final group = _groupBox.get(activeId);
    // If isShared is true, we proceed with API calls
    return group?.isShared ?? false;
  }

  // --- GROUP LOGIC ---

  List<GroceryGroup> getAllGroups() {
    return _groupBox.values.toList();
  }

  Future<void> createGroup(String name, {bool isShared = false}) async {
    final id = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final newGroup = GroceryGroup(id: id, name: name, isShared: isShared);

    await _groupBox.put(id, newGroup);

    // Sync group creation to Postgres if shared
    if (isShared) {
      await _syncService.createGroupOnServer(newGroup);
    }

    if (_metaBox.get('activeGroupId') == null) {
      await setActiveGroup(id);
    }
  }

  String getActiveGroupId() {
    return _metaBox.get('activeGroupId') ?? 'default';
  }

  Future<void> setActiveGroup(String groupId) async {
    await _metaBox.put('activeGroupId', groupId);
  }

  // --- LIST LOGIC ---

  List<GroceryList> getListsForGroup(String groupId) {
    return _listBox.values
        .where((l) => l.groupId == groupId && !l.isArchived)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> createList(String name, String groupId) async {
    final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
    final newList = GroceryList(
        id: id,
        name: name,
        groupId: groupId,
        createdAt: DateTime.now()
    );

    // 1. Always Save Locally (Hive)
    await _listBox.put(id, newList);

    // 2. Conditional Sync (Express)
    if (_shouldSync()) {
      await _syncService.createListOnServer(newList);
    }
  }

  // --- ITEM LOGIC ---

  List<GroceryItem> getItemsForList(String listId) {
    return _itemBox.values.where((item) => item.listId == listId).toList();
  }

  Future<void> addItemToList(String name, String listId, String groupId) async {
    final newItem = GroceryItem(
      name: name,
      status: ItemStatus.pending,
      createdAt: DateTime.now(),
      listId: listId,
      groupId: groupId,
    );

    await _itemBox.add(newItem);

    // Sync item to server if group is shared
    if (_shouldSync()) {
      // You'll want to add this method to your SyncService
      await _syncService.addItemOnServer(newItem);
    }
  }

  Future<void> updateItemStatus(GroceryItem item, ItemStatus newStatus) async {
    item.status = newStatus;
    await item.save();

    if (_shouldSync()) {
      // Notify server of the status change (bought/discarded)
      await _syncService.updateItemOnServer(item);
    }
  }

  // --- CARRY OVER / ARCHIVE LOGIC ---

  Future<void> carryOverToNewList(String oldListId, String newListName) async {
    final oldList = _listBox.get(oldListId);
    if (oldList == null) return;

    final groupId = oldList.groupId;

    // Use the existing createList logic which handles the sync check internally
    await createList(newListName, groupId);

    // Get the ID of the list we just created (the most recent one)
    final newListId = getListsForGroup(groupId).first.id;

    final carryOverItems = _itemBox.values.where((item) =>
    item.listId == oldListId &&
        item.status == ItemStatus.pending
    ).toList();

    for (var item in carryOverItems) {
      await addItemToList(item.name, newListId, groupId);
    }

    oldList.isArchived = true;
    await oldList.save();

    // Optional: Update archive status on server
    if (_shouldSync()) {
      await _syncService.archiveListOnServer(oldListId);
    }
  }

  Future<void> deleteItem(GroceryItem item) async {
    final bool shared = _shouldSync();
    final String itemId = item.key.toString(); // or however you track IDs on server

    await item.delete();

    if (shared) {
      await _syncService.deleteItemOnServer(item.name, itemId);
    }
  }
}