import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';

enum ItemSortType { alphabetical, created, status, hasNote, hasImage }

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

  ItemSortType _currentSort = ItemSortType.created;
  bool _isInverse = false;

  ItemSortType get currentSort => _currentSort;
  bool get isInverse => _isInverse;

  ItemController({required this.repository});


  void setOpenedList(String? listId) {
    _currentListId = listId;
    print("📍 UI State: User is now viewing list: $listId");
  }

  void setSort(ItemSortType type, {bool? inverse}) {
    _currentSort = type;
    if (inverse != null) _isInverse = inverse;

    final metaBox = Hive.box<String>('metadata');
    metaBox.put('sort_type', type.name);
    metaBox.put('sort_inverse', _isInverse.toString());

    applySort();
  }

  void applySort() {
    _currentItems.sort((a, b) {
      int cmp;
      switch (_currentSort) {
        case ItemSortType.alphabetical:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case ItemSortType.hasNote:
          cmp = (b.note?.length ?? 0).compareTo(a.note?.length ?? 0);
          break;
        case ItemSortType.hasImage:
          int aHas = a.imagePath != null ? 1 : 0;
          int bHas = b.imagePath != null ? 1 : 0;
          cmp = bHas.compareTo(aHas);
          break;
        case ItemSortType.created:
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _isInverse ? -cmp : cmp;
    });
    notifyListeners();
  }

  Future<void> syncFromSocket(String eventType, Map<String, dynamic> data) async {
    final String? incomingListId = data['listId']?.toString();

    if (_currentListId != incomingListId) return;

    final GroceryItem socketItem = GroceryItem.fromJson(data);

    switch (eventType) {
      case 'item_added':
        final exists = _currentItems.any((i) => i.id == socketItem.id || (i.id == -1 && i.name == socketItem.name));
        if (!exists) {
          _currentItems.insert(0, socketItem);
        } else if (socketItem.id != -1) {
          int tempIndex = _currentItems.indexWhere((i) => i.id == -1 && i.name == socketItem.name);
          if (tempIndex != -1) _currentItems[tempIndex] = socketItem;
        }
        break;

      case 'item_updated':
        int index = _currentItems.indexWhere((i) => i.id == socketItem.id);
        if (index != -1) {
          _currentItems[index] = socketItem;
        }
        break;

      case 'item_removed':
      case 'item_deleted':
        _currentItems.removeWhere((i) => i.id == socketItem.id);
        break;
    }

    applySort();
    notifyListeners();
  }

  // --- CORE OPTIMISTIC METHODS ---

  /// Toggle status happens INSTANTLY in the UI
  Future<void> toggleStatus(GroceryItem item, String groupId, {String? forceStatus}) async {
    final oldStatus = item.status;

    ItemStatus targetStatus;
    if (forceStatus != null) {
      targetStatus = ItemStatus.values.firstWhere(
            (e) => e.name == forceStatus,
        orElse: () => ItemStatus.pending,
      );
    } else {
      targetStatus = (oldStatus == ItemStatus.bought) ? ItemStatus.pending : ItemStatus.bought;
    }

    item.status = targetStatus;
    notifyListeners();

    try {
      await repository.updateItem(item, groupId);
      _errorMessage = null;
    } catch (e) {
      if (e.toString().contains("queued") || e.toString().contains("Offline")) {
        debugPrint("Sync pending: Status change added to queue.");
      } else {
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