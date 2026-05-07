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

  Future<void> loadItems(String listId, String groupId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentItems = await repository.getItems(listId, groupId);
    } catch (e) {
      _errorMessage = "Offline: Unable to load items.";
      _currentItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem({
    required String name,
    required String listId,
    required String groupId,
    String? note,
    File? imageFile,
  }) async {
    _isLoading = true;
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
      _errorMessage = "Failed to add item to server.";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStatus(GroceryItem item, String groupId, {String? forceStatus}) async {
    final oldStatus = item.status;

    ItemStatus targetStatus;
    if (forceStatus != null) {
      targetStatus = ItemStatus.values.firstWhere(
            (e) => e.name == forceStatus,
        orElse: () => ItemStatus.pending,
      );
    } else {
      targetStatus = (oldStatus == ItemStatus.bought)
          ? ItemStatus.pending
          : ItemStatus.bought;
    }

    item.status = targetStatus;
    notifyListeners();

    try {
      await repository.updateItem(item, groupId);
      _errorMessage = null;
    } catch (e) {
      debugPrint("Toggle failed: $e");
      _errorMessage = "Sync failed: Status could not be saved.";
      item.status = oldStatus;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateItem(GroceryItem item, String groupId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.updateItem(item, groupId);
      await loadItems(item.listId, groupId);
    } catch (e) {
      _errorMessage = "Update failed.";
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

  Future<void> removeItem(GroceryItem item, String groupId) async {
    try {
      await repository.deleteItem(item, groupId);
      _currentItems.removeWhere((i) => i.id == item.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = "Could not delete item.";
      notifyListeners();
    }
  }
}