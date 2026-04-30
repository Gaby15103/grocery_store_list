import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../models/user_profile.dart';
import '../services/socket_service.dart';
import '../services/sync_service.dart';
import '../utils.dart';
import '../utils/ui_helpers.dart';

class GroceryRepository {
  final Box<GroceryItem> _itemBox = Hive.box<GroceryItem>('items');
  final Box<GroceryGroup> _groupBox = Hive.box<GroceryGroup>('groups');
  final Box<GroceryList> _listBox = Hive.box<GroceryList>('lists');
  final Box<String> _metaBox = Hive.box<String>('metadata');
  final SyncService _syncService = SyncService();
  final Utils _utils = Utils();

  void initSocketListener(Stream<SocketEvent> eventStream) {
    eventStream.listen((event) {
      switch (event.type) {
        case 'item_added':
          handleSocketItemAdded(event.data);
          break;
        case 'item_updated':
          handleSocketItemUpdated(event.data);
          break;
        case 'item_deleted':
          handleSocketItemDeleted(event.data);
          break;
        case 'force_refresh':
          initialize();
          break;
      }
    });
  }

  // --- HELPER LOGIC ---

  /// Checks if the current active group is marked as shared/server-side
  bool _shouldSync() {
    final activeId = getActiveGroupId();
    final group = _groupBox.get(activeId);
    // If isShared is true, we proceed with API calls
    return group?.isShared ?? false;
  }

  Future<void> initialize() async {
    final email = getUserEmail();
    print(email);

    if (email != null) {
      await syncUserToServer();

      final remoteGroups = await _syncService.fetchGroupsFromServer();

      for (var group in remoteGroups) {
        await _groupBox.put(group.id, group);
      }
    }

    // 3. Ensure we have an active group selected
    if (getActiveGroupId() == 'default' && _groupBox.isNotEmpty) {
      await setActiveGroup(_groupBox.keys.first);
    }
  }

  Future<void> resetAppDatabase() async {
    // Use a try-catch to handle any file locks on your Arch system
    try {
      // 1. Clear the data first while boxes are open (safer for the UI)
      await Hive.box<GroceryItem>('items').clear();
      await Hive.box<GroceryGroup>('groups').clear();
      await Hive.box<GroceryList>('lists').clear();
      await Hive.box<String>('metadata').clear();

      // 2. Actually delete the files if you want a 100% clean slate

      print("Hive cache cleared successfully.");
    } catch (e) {
      print("Error during database reset: $e");
      rethrow;
    }
  }

  String getSyncCode() {
    return _metaBox.get('deviceId') ?? "Not Generated";
  }

  /// Helper for the Socket Service to know which room to join
  String? getActiveGroupIdForSocket() {
    final id = getActiveGroupId();
    return id == 'default' ? null : id;
  }

  String? currentOpenedListId;

  void setCurrentlyViewedList(String? listId) {
    currentOpenedListId = listId;
    print("📍 User is now viewing list: $listId");
  }

  // --- SOCKET SYNC LOGIC ---

  /// Called when the socket receives 'item_added'
  Future<void> handleSocketItemAdded(Map<String, dynamic> data) async {
    try {
      final newItem = GroceryItem.fromJson(data);
      // Writing to the box triggers ValueListenableBuilder in the UI
      await _itemBox.put('${newItem.listId}_${newItem.name}', newItem);
    } catch (e) {
      print("❌ Error handling socket item add: $e");
    }
  }

  /// Called when the socket receives 'item_updated'
  Future<void> handleSocketItemUpdated(Map<String, dynamic> data) async {
    print('item updated');
    final String name = data['name'];
    final String listId = data['listId'];
    final String statusStr = data['status'];

    final key = '${listId}_$name';
    final item = _itemBox.get(key);

    if (item != null) {
      item.status = _statusFromSocketString(statusStr);

      await _itemBox.put(key, item);
    }
  }

  void handleSocketItemDeleted(Map<String, dynamic> data) {
    _itemBox.delete('${data['listId']}_${data['name']}');
  }

  /// Helper to map socket strings to your Enum
  ItemStatus _statusFromSocketString(String status) {
    return ItemStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ItemStatus.pending,
    );
  }

  // --- USER LOGIC ---

  /// Returns the email stored during setup, or null if first run
  String? getUserEmail() {
    return _metaBox.get('userEmail');
  }

  Future<User> getCurrentUser() async {
    final data = await _syncService.getCurrentUser();
    return User.fromJson(data);
  }

  Future<UserProfile> getUserProfile(String email) async {
    final data = await _syncService.getUserProfile(email);
    return UserProfile.fromJson(data);
  }

  /// Saves initial user info to Hive
  Future<void> setUserDetails({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _metaBox.put('firstName', firstName);
    await _metaBox.put('lastName', lastName);
    await _metaBox.put('userEmail', email);
  }

  /// Registers the user on your Express/Postgres backend
  Future<void> syncUserToServer() async {
    final firstName = _metaBox.get('firstName');
    final lastName = _metaBox.get('lastName');
    final email = _metaBox.get('userEmail');
    final deviceId = await _utils.getUniqueDeviceId();

    if (firstName != null && lastName != null && email != null) {
      await _syncService.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        deviceId: deviceId,
      );
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _syncService.updateUserProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );

    await _metaBox.put('firstName', firstName);
    await _metaBox.put('lastName', lastName);
    await _metaBox.put('userEmail', email);
  }

  /// Use this to link this device to an existing account using a Sync Code
  Future<void> linkAccount(String targetSyncCode) async {
    try {
      final deviceId = await _utils.getUniqueDeviceId();
      final userData = await _syncService.linkDevices(
        currentDeviceId: deviceId,
        targetCode: targetSyncCode,
      );

      await _metaBox.put('userEmail', userData['email']);
      await _metaBox.put('firstName', userData['firstName']);
      await _metaBox.put('lastName', userData['lastName']);

      await initialize();
    } catch (e) {
      print("Failed to link account: $e");
      rethrow;
    }
  }

  Future<List<String>> getRecentContacts() async {
    return await _syncService.fetchRecentContacts();
  }

  // --- INVITATION LOGIC ---

  /// Fetches invitations where the status is 'pending' for this user
  Future<List<dynamic>> getPendingInvitations() async {
    return await _syncService.fetchPendingInvites();
  }

  /// Sends an invitation to a specific email for the currently active group
  Future<void> sendInvitation(String targetEmail, String activeGroupId) async {
    final myEmail = getUserEmail();
    if (myEmail == null) {
      UIHelpers.showNotification("Login required to send invites.");
      return;
    }
    await _syncService.sendInvite(activeGroupId, targetEmail);
  }

  /// Accepts a group invitation and refreshes the local group list
  Future<void> acceptInvitation(String groupId) async {
    await _syncService.respondToInvite(groupId, 'accepted');

    // Re-run initialize to pull the newly joined group into Hive
    await initialize();
  }

  // --- GROUP LOGIC ---

  Future<void> makeGroupPublic(String groupId) async {
    try {
      // 1. Find the group in your Hive box
      final box = Hive.box<GroceryGroup>('groups');
      final group = box.get(groupId);

      if (group != null) {
        group.isShared = true;
        await box.put(groupId, group);

        await _syncService.createGroupOnServer(group);
        await _syncService.createGroupOnServer(group);

        print('Group $groupId is now public and synced.');
      }
    } catch (e) {
      throw Exception("Failed to make group public: $e");
    }
  }

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

    final group = _groupBox.get(groupId);
    if (group != null && group.isShared) {
      final remoteLists = await _syncService.fetchListsFromServer(groupId);

      for (var list in remoteLists) {
        await _listBox.put(list.id, list);
      }
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await _syncService.deleteGroup(id);
    } catch (e) {
      debugPrint("Sync failed, but proceeding with local delete: $e");
    }

    await Hive.box<GroceryGroup>('groups').delete(id);

    final listBox = Hive.box<GroceryList>('lists');
    final listsToRemove = listBox.values
        .where((l) => l.groupId == id)
        .toList();

    for (var list in listsToRemove) {

      await listBox.delete(list.id);
    }
  }

  // --- LIST LOGIC ---

  List<GroceryList> getListsForGroup(String groupId) {
    return _listBox.values
        .where((l) => l.groupId == groupId && !l.isArchived)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<GroceryList?> createList(String name, String groupId) async {
    final id = 'list_${DateTime.now().millisecondsSinceEpoch}';

    final newList = GroceryList(
      id: id,
      name: name,
      groupId: groupId,
      createdAt: DateTime.now(),
    );

    await _listBox.put(id, newList);

    if (_shouldSync()) {
      final syncedList = await _syncService.createListOnServer(newList);
      if (syncedList != null) {
        await _listBox.put(syncedList.id, syncedList);
        return syncedList;
      }
    }

    return newList;
  }

  Future<void> deleteList(String listId) async {
    // 1. Sync with API
    await _syncService.deleteList(listId);

    // 2. Local Cleanup
    final listBox = Hive.box<GroceryList>('lists');
    await listBox.delete(listId);

    // 3. Clean up items belonging to this list
    final itemBox = Hive.box<GroceryItem>('items');
    final itemsToDelete = itemBox.values.where((item) => item.listId == listId).map((e) => e.id);
    for (var id in itemsToDelete) {
      await itemBox.delete(id);
    }
  }

  // --- ITEM LOGIC ---

  Future<List<GroceryItem>> getItemsForList(String listId) async {
    if (_shouldSync()) {
      // 1. Fetch from server
      final remoteItems = await _syncService.fetchItemFromList(listId);

      // 2. IMPORTANT: Save them into Hive so the ValueListenableBuilder sees them
      for (var item in remoteItems) {
        // Use a unique key to prevent duplicates
        await _itemBox.put('${item.listId}_${item.name}', item);
      }
      return remoteItems;
    }

    return _itemBox.values.where((item) => item.listId == listId).toList();
  }


  Future<void> addItemToList(
    String name,
    String listId,
    String groupId,
    String? note,
    File? imageFile,
  ) async {
    String? finalImagePath;

    if (imageFile != null && _shouldSync()) {
      finalImagePath = await _syncService.uploadFile(imageFile);
    } else if (imageFile != null) {
      finalImagePath = imageFile.path;
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

    await _itemBox.put('${listId}_$name', newItem);

    if (_shouldSync()) {
      await _syncService.addItemOnServer(newItem);
    }
  }

  Future<void> updateItemStatus(GroceryItem item, ItemStatus newStatus) async {
    item.status = newStatus;

    await item.save();

    if (_shouldSync()) {
      // Update the record in Postgres
      await _syncService.updateItemOnServer(item, getActiveGroupId());
    }
  }

  Future<void> updateItemDetails({
    required GroceryItem item,
    required String newName,
    String? newNote,
    File? newImageFile,
    bool shouldClearImage = false,
  }) async {
    // 1. Handle Image Logic
    if (shouldClearImage) {
      item.imagePath = null;
    } else if (newImageFile != null) {
      // If shared, upload to server; otherwise, save local path
      if (_shouldSync()) {
        final serverPath = await _syncService.uploadFile(newImageFile);
        if (serverPath != null) item.imagePath = serverPath;
      } else {
        item.imagePath = newImageFile.path;
      }
    }

    // 2. Update Basic Fields
    item.name = newName;
    item.note = newNote;

    // 3. Save Locally
    await item.save();

    // 4. Sync to Server
    if (_shouldSync()) {
      await _syncService.updateItemOnServer(item, getActiveGroupId());
    }
  }

  // --- CARRY OVER / ARCHIVE LOGIC ---

  Future<String?> carryOverToNewList(String oldListId, String newListName) async {
    final oldList = _listBox.get(oldListId);
    if (oldList == null) return null;

    final groupId = oldList.groupId;

    final newList = await createList(newListName, groupId);

    if (newList == null) {
      debugPrint("Failed to create new list for carry over.");
      return null;
    }

    final newListId = newList.id;

    final carryOverItems = _itemBox.values
        .where((item) => item.listId == oldListId && item.status == ItemStatus.pending)
        .toList();

    for (var item in carryOverItems) {
      final newItem = GroceryItem(
        name: item.name,
        status: ItemStatus.pending,
        createdAt: DateTime.now(),
        listId: newListId,
        groupId: groupId,
        note: item.note,
        imagePath: item.imagePath,
      );

      await _itemBox.put('${newListId}_${newItem.name}', newItem);

      if (_shouldSync()) {
        await _syncService.addItemOnServer(newItem);
      }
    }

    oldList.isArchived = true;
    await oldList.save();

    if (_shouldSync()) {
      await _syncService.archiveListOnServer(oldListId);
    }

    return newListId;
  }

  Future<void> deleteItem(GroceryItem item) async {
    if (_shouldSync()) {
      await _syncService.deleteItemOnServer(
        item.name,
        item.listId,
        getActiveGroupId(),
      );
    } else {
      await item.delete();
    }
  }
}
