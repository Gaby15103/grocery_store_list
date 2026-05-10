import 'dart:io';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';

class ItemController extends ChangeNotifier {
  final ItemRepository repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _currentListId;
  String? get currentListId => _currentListId;

  List<GroceryItem> _currentItems = [];
  List<GroceryItem> get currentItems => _currentItems;

  ItemController({required this.repository});

  void setOpenedList(String? listId) {
    _currentListId = listId;
    print("📍 UI State: User is now viewing list: $listId");
  }

  // --- CORE OPTIMISTIC METHODS ---

  /// Toggle status happens INSTANTLY in the UI
  Future<void> toggleStatus(GroceryItem item, String groupId, {String? forceStatus}) async {
    final oldStatus = item.status;

    // Determine target
    ItemStatus targetStatus;
    if (forceStatus != null) {
      targetStatus = ItemStatus.values.firstWhere(
            (e) => e.name == forceStatus,
        orElse: () => ItemStatus.pending,
      );
    } else {
      targetStatus = (oldStatus == ItemStatus.bought) ? ItemStatus.pending : ItemStatus.bought;
    }

    // 1. Optimistic Update
    item.status = targetStatus;
    notifyListeners();

    try {
      await repository.updateItem(item, groupId);
      _errorMessage = null;
    } catch (e) {
      // 2. Handle specific network failures (Queueing)
      if (e.toString().contains("queued") || e.toString().contains("Offline")) {
        debugPrint("Sync pending: Status change added to queue.");
        // We DON'T rollback here because the SyncManager will handle it eventually
      } else {
        // 3. Rollback for permanent server errors
        item.status = oldStatus;
        _errorMessage = "Sync failed: Server rejected the change.";
        notifyListeners();
      }
    }
  }

  /// Add item without blocking the whole screen
  Future<void> addItem({
    required String name,
    required String listId,
    required String groupId,
    String? note,
    File? imageFile,
  }) async {
    final tempItem = GroceryItem(
      id: -1,
      name: name,
      listId: listId,
      groupId: groupId,
      status: ItemStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );

    _currentItems.insert(0, tempItem);
    notifyListeners();

    try {
      await repository.addItemToList(
        name: name,
        listId: listId,
        groupId: groupId,
        note: note,
        imageFile: imageFile,
      );

      await loadItems(listId, groupId);
    } catch (e) {
      if (e.toString().contains("queued") || e.toString().contains("Offline")) {
      } else {
        _currentItems.remove(tempItem);
        _errorMessage = "Failed to add item.";
        notifyListeners();
      }
    }
  }
  /// Delete item instantly
  Future<void> removeItem(GroceryItem item, String groupId) async {
    final index = _currentItems.indexOf(item);

    // 1. Optimistic Remove
    _currentItems.remove(item);
    notifyListeners();

    try {
      await repository.deleteItem(item, groupId);
    } catch (e) {
      if (e.toString().contains("queued") || e.toString().contains("Offline")) {
        // Success (it's queued)
      } else {
        // Rollback if server refused
        if (index != -1) _currentItems.insert(index, item);
        _errorMessage = "Could not delete item.";
        notifyListeners();
      }
    }
  }

  // --- STANDARD METHODS ---

  Future<void> loadItems(String listId, String groupId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentItems = await repository.getItems(listId, groupId);
    } catch (e) {
      _errorMessage = "Offline: Showing cached items.";
      // Note: Items are still in _currentItems from Hive in repo
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateItemDetails({
    required GroceryItem item,
    required String newName,
    String? newNote,
    File? newImageFile,
    bool shouldClearImage = false,
    String? groupId,
  }) async {
    // Details updates usually involve images/heavy text, so we keep the loader
    _isLoading = true;
    notifyListeners();

    try {
      await repository.updateItemDetails(
        item: item,
        newName: newName,
        newNote: newNote,
        newImageFile: newImageFile,
        shouldClearImage: shouldClearImage,
        groupId: groupId ?? 'default',
      );
      await loadItems(item.listId, groupId ?? 'default');
    } catch (e) {
      _errorMessage = "Update failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}