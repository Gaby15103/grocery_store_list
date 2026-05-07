import 'dart:io';
import 'package:grocery_list/services/api/group_api_client.dart';
import 'package:hive/hive.dart';
import '../models/group.dart';
import '../models/item.dart';
import '../services/api/item_api_client.dart';

class ItemRepository {
  final ItemApiClient _api;
  final GroupApiClient _grApi;
  final Box<GroceryGroup> _groupBox = Hive.box<GroceryGroup>('groups');

  ItemRepository(this._api, this._grApi);

  Future<bool> _isShared(String groupId) async {
    print("DEBUG: Entrée dans _isShared pour $groupId");
    if (groupId == 'default') {
      return false;
    }
    var group = _groupBox.get(groupId);
    group ??= await _grApi.fetchGroup(groupId);
    return group.isShared;
  }

  /// GET: Absolute truth from server
  Future<List<GroceryItem>> getItems(String listId, String groupId) async {
    if (await _isShared(groupId)) {
      return await _api.fetchItems(listId);
    }
    return []; // Logic for local groups can be added here later
  }

  /// POST: Creates item on server and gets the Real ID
  Future<void> addItemToList({
    required String name,
    required String listId,
    required String groupId,
    String? note,
    File? imageFile,
  }) async {
    if (!await _isShared(groupId)) return;

    String? finalImagePath;
    if (imageFile != null) {
      finalImagePath = await _api.uploadImage(imageFile);
    }

    final newItem = GroceryItem(
      name: name,
      status: ItemStatus.pending,
      createdAt: DateTime.now(),
      listId: listId,
      groupId: groupId,
      note: note,
      imagePath: finalImagePath,
    );

    final serverItem = await _api.addItem(newItem);
    newItem.id = serverItem.id;
  }

  /// PUT: Update the item
  Future<void> updateItem(GroceryItem item, String groupId) async {
    if (await _isShared(groupId)) {
      await _api.updateItem(item, groupId);
    }
  }

  Future<void> updateItemDetails({
    required GroceryItem item,
    required String newName,
    String? newNote,
    File? newImageFile,
    bool shouldClearImage = false,
    required String groupId,
  }) async {

    item.name = newName;
    item.note = newNote;

    if (!await _isShared(groupId)) {
      if (shouldClearImage) {
        item.imagePath = null;
      } else if (newImageFile != null) {
        item.imagePath = newImageFile.path;
      }
      await item.save();
      return;
    }

    if (shouldClearImage) {
      item.imagePath = null;
    } else if (newImageFile != null) {
      final String? uploadedPath = await _api.uploadImage(newImageFile);
      if (uploadedPath != null) {
        item.imagePath = uploadedPath;
      }
    }

    await _api.updateItem(item, groupId);
  }

  /// DELETE: Remove from server
  Future<void> deleteItem(GroceryItem item, String groupId) async {
    final bool shared = await _isShared(groupId);

    print("is shared: $shared");
    print("id is not null: ${item.id != null}");

    if (shared && item.id != null) {
      await _api.deleteItem(item.id!, item.name, item.listId, item.groupId);
    }
  }
}