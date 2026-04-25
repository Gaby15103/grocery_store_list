import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';
import '../services/sync_service.dart';
import '../utils/ui_helpers.dart';

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

  Future<void> initialize() async {
    final email = getUserEmail();
    print(email);

    if (email != null){
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
      await Hive.deleteBoxFromDisk('items');
      await Hive.deleteBoxFromDisk('groups');
      await Hive.deleteBoxFromDisk('lists');
      await Hive.deleteBoxFromDisk('metadata');

      print("Hive cache cleared successfully.");
    } catch (e) {
      print("Error during database reset: $e");
      rethrow;
    }
  }

  String getSyncCode() {
    return _metaBox.get('deviceId') ?? "Not Generated";
  }

  // --- USER LOGIC ---

  Future<String> getUniqueDeviceId() async {
    String? existingId = _metaBox.get('deviceId');
    if (existingId != null) return existingId;

    var deviceInfo = DeviceInfoPlugin();
    String id = 'unknown';


    if (Platform.isLinux) {
      var linuxInfo = await deviceInfo.linuxInfo;
      id = linuxInfo.machineId ?? 'linux_unknown';
    } else if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      id = androidInfo.id;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      id = iosInfo.identifierForVendor ?? 'ios_unknown';
    }

    await _metaBox.put('deviceId', id);
    return id;
  }

  /// Returns the email stored during setup, or null if first run
  String? getUserEmail() {
    return _metaBox.get('userEmail');
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
    final deviceId = await getUniqueDeviceId();

    if (firstName != null && lastName != null && email != null) {
      await _syncService.registerUser(
          firstName: firstName,
          lastName: lastName,
          email: email,
          deviceId: deviceId
      );
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email
  }) async {
    await _syncService.updateUserProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );

    await _metaBox.put('firstName', firstName);
    await _metaBox.put('lastName', lastName);
    await _metaBox.put('userEmail', email);

    print("Profile updated successfully for $email");
  }

  /// Use this to link this device to an existing account using a Sync Code
  Future<void> linkAccount(String targetSyncCode) async {
    try {
      final deviceId = await getUniqueDeviceId();
      await _syncService.linkDevices(currentDeviceId: deviceId, targetCode: targetSyncCode);

      await initialize();
    } catch (e) {
      print("Failed to link account: $e");
      rethrow;
    }
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

    if (_shouldSync()) {
      await _syncService.createListOnServer(newList);

    }else{
      await _listBox.put(id, newList);
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

  Future<void> addItemToList(String name, String listId, String groupId) async {
    final newItem = GroceryItem(
      name: name,
      status: ItemStatus.pending,
      createdAt: DateTime.now(),
      listId: listId,
      groupId: groupId,
    );

    // 1. ALWAYS save to Hive first. This triggers the UI instantly.
    await _itemBox.put('${listId}_$name', newItem);

    // 2. Then sync to server if needed
    if (_shouldSync()) {
      await _syncService.addItemOnServer(newItem);
    }
  }

  Future<void> updateItemStatus(GroceryItem item, ItemStatus newStatus) async {
    item.status = newStatus;

    if (_shouldSync()) {
      // Update the record in Postgres
      await _syncService.updateItemOnServer(item);
    } else {
      // Update the record in Hive
      await item.save();
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
    if (_shouldSync()) {
      await _syncService.deleteItemOnServer(item.name, item.listId);
    } else {
      await item.delete();
    }
  }
}