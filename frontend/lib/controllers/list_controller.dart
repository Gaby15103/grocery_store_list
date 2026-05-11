import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/group_list.dart';
import '../repositories/list_repository.dart';

class ListController extends ChangeNotifier {
  final ListRepository repository;

  List<GroceryList> _lists = [];
  List<GroceryList> get lists => _lists;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _currentListId;
  String? get currentListId => _currentListId;

  ListController({required this.repository});

  Future<void> loadLists(String groupId, bool isShared) async {
    _isLoading = true;
    notifyListeners();

    _lists = await repository.getLists(groupId, isShared);
    _lists.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _isLoading = false;
    notifyListeners();
  }

  void setOpenedList(String? id) {
    _currentListId = id;
    notifyListeners();
  }

  Future<void> createList(String name, String groupId, bool isShared) async {
    await repository.addList(name, groupId, isShared);
    await loadLists(groupId, isShared);
  }

  Future<void> deleteList(String listId, String groupId, bool isShared) async {
    await repository.removeList(listId, isShared);
    await loadLists(groupId, isShared);
  }

  Future<void> archiveList(String listId, String newName, String groupId, bool isShared) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newList = await repository.archiveAndCarryOver(listId, newName, groupId, isShared);

      setOpenedList(newList.id);

      await loadLists(groupId, isShared);
    } catch (e) {
      debugPrint("Archive Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}