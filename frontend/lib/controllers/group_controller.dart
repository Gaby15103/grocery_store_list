import 'package:flutter/material.dart';
import '../models/group.dart';
import '../repositories/group_repository.dart';
import '../services/socket_service.dart';

class GroupController extends ChangeNotifier {
  final GroupRepository repository;
  final SocketService socketService;

  List<GroceryGroup> _groups = [];
  List<GroceryGroup> get groups => _groups;

  String? _activeGroupId;
  String? get activeGroupId => _activeGroupId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  GroupController({required this.repository, required this.socketService}) {
    _groups = repository.getCachedGroups();
    _activeGroupId = repository.getActiveGroupId();
    _connectSocket();
  }

  void _connectSocket() {
    if (_activeGroupId != null && _activeGroupId != 'default') {
      socketService.joinGroup(_activeGroupId!);
    }
  }

  bool get isCurrentGroupShared {
    final group = groups.firstWhere(
          (g) => g.id == activeGroupId,
      orElse: () => GroceryGroup(id: '', name: '', isShared: false),
    );
    return group.isShared;
  }

  /// Called by the UI (e.g., Pull-to-Refresh)
  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();

    _groups = await repository.refreshGroups();

    _isLoading = false;
    notifyListeners();
  }

  /// Changes the active group and handles the Socket Room swap
  Future<void> changeActiveGroup(String id) async {
    await repository.saveActiveGroupId(id);
    _activeGroupId = id;

    socketService.joinGroup(id);

    notifyListeners();
  }

  Future<void> makeGroupPublic(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.makeGroupPublic(id);
      await loadGroups();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createGroup(String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.createGroup(name);
      await loadGroups();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteGroup(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.removeGroup(id);
      _activeGroupId = repository.getActiveGroupId();
      await loadGroups();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}