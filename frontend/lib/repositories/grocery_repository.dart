import 'package:hive/hive.dart';
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';

class GroceryRepository {
  final Box<GroceryItem> _itemBox = Hive.box<GroceryItem>('items');
  final Box<GroceryGroup> _groupBox = Hive.box<GroceryGroup>('groups');
  final Box<GroceryList> _listBox = Hive.box<GroceryList>('lists');
  final Box<String> _metaBox = Hive.box<String>('metadata');

  // --- GROUP LOGIC ---

  List<GroceryGroup> getAllGroups() {
    // Return all groups. If empty, you might want to seed a 'Personal' group in main.dart
    return _groupBox.values.toList();
  }

  Future<void> createGroup(String name) async {
    final id = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final newGroup = GroceryGroup(id: id, name: name);
    await _groupBox.put(id, newGroup);
    // Auto-set as active if it's the first one
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

  // --- LIST LOGIC (Replaces old Session logic) ---

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
    await _listBox.put(id, newList);
  }

  // --- ITEM LOGIC ---

  /// Gets items for a specific list (used by HomeScreen)
  List<GroceryItem> getItemsForList(String listId) {
    return _itemBox.values.where((item) => item.listId == listId).toList();
  }

  /// Adds an item to a specific list
  Future<void> addItemToList(String name, String listId, String groupId) async {
    final newItem = GroceryItem(
      name: name,
      status: ItemStatus.pending,
      createdAt: DateTime.now(),
      listId: listId,
      groupId: groupId,
    );
    await _itemBox.add(newItem);
  }

  /// Updates status based on the list currently being viewed
  Future<void> updateItemStatus(GroceryItem item, ItemStatus newStatus) async {
    item.status = newStatus;
    await item.save();
  }

  // --- CARRY OVER / ARCHIVE LOGIC ---

  /// Archives the current list and moves pending items to a new list
  Future<void> carryOverToNewList(String oldListId, String newListName) async {
    final oldList = _listBox.get(oldListId);
    if (oldList == null) return;

    final groupId = oldList.groupId;

    // 1. Create the new list
    final newListId = 'list_${DateTime.now().millisecondsSinceEpoch}';
    final newList = GroceryList(
      id: newListId,
      name: newListName,
      groupId: groupId,
      createdAt: DateTime.now(),
    );
    await _listBox.put(newListId, newList);

    // 2. Identify items to move
    final carryOverItems = _itemBox.values.where((item) =>
    item.listId == oldListId &&
        item.status == ItemStatus.pending
    ).toList();

    // 3. Clone pending items into the new list
    for (var item in carryOverItems) {
      final newItem = GroceryItem(
        name: item.name,
        status: ItemStatus.pending,
        createdAt: DateTime.now(),
        listId: newListId,
        groupId: groupId,
      );
      await _itemBox.add(newItem);
    }

    // 4. Archive the old list
    oldList.isArchived = true;
    await oldList.save();
  }

  Future<void> deleteItem(GroceryItem item) async {
    await item.delete();
  }
}