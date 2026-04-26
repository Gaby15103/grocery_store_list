import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';
import '../utils.dart';

class SyncService {

  final Utils _utils = Utils();

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  // --- USER SYNC ---

  Future<Map<String, String>> get _headers async {
    final email = Hive.box<String>('metadata').get('userEmail');
    return {
      'Content-Type': 'application/json',
      'x-user-email': email ?? '',
      'x-device-id': await _utils.getUniqueDeviceId(),
    };
  }

// --- USER & INVITATION SYNC ---

  Future<void> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String deviceId,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'deviceId': deviceId,
        }),
      );
    } catch (e) {
      print('Register user error: $e');
    }
  }

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
      }),
    );

    if (response.statusCode == 409) {
      throw Exception("409: Email already in use");
    } else if (response.statusCode != 200) {
      throw Exception("Failed to update profile on server: ${response.body}");
    }
  }

  Future<void> sendInvite(String groupId, String targetEmail) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/invite'),
      headers: await _headers,
      body: jsonEncode({'email': targetEmail}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send invitation: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchPendingInvites() async {
    try {
      print("test");
      final response = await http.get(
        Uri.parse('$baseUrl/users/invitations'),
        headers: await _headers,
      );
      if (response.statusCode == 200) {
        print(response.body);
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Fetch invites error: $e');
    }
    return [];
  }

  Future<void> respondToInvite(String groupId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/groups/$groupId/invite/respond'),
        headers: await _headers,
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode != 200) {
        print('Invite response failed: ${response.body}');
      }
    } catch (e) {
      print('Respond to invite error: $e');
    }
  }

  Future<Map<String, dynamic>> linkDevices({
    required String currentDeviceId,
    required String targetCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/link'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'currentDeviceId': currentDeviceId,
        'targetSyncCode': targetCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user'];
    } else {
      throw Exception("Failed to link devices: ${response.body}");
    }
  }

  Future<List<String>> fetchRecentContacts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/contacts'),
      headers: await _headers,
    );
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((u) => u['email'] as String).toList();
    }
    return [];
  }


  Future<List<GroceryGroup>> fetchGroupsFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups'),
        headers: await _headers,
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroceryGroup(
          id: json['id'],
          name: json['name'],
          isShared: true,
        )).toList();
      }
    } catch (e) {
      print('Failed to fetch groups: $e');
    }
    return [];
  }

  Future<List<GroceryItem>> fetchItemFromList(String id) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/lists/$id/items'),
          headers: await _headers
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroceryItem(
          // Use ?? to provide defaults if the DB has nulls
            name: json['name'] ?? 'Unknown Item',
            status: ItemStatus.values.firstWhere(
                    (e) => e.name == json['status'],
                orElse: () => ItemStatus.pending
            ),
            // Check if createdAt exists before parsing
            createdAt: json['createdAt'] != null
                ? DateTime.parse(json['createdAt'])
                : DateTime.now(),
            listId: json['listId'] ?? id, // Fallback to the ID passed in
            groupId: json['groupId'] ?? '' // Ensure this isn't null
        )).toList();
      }
    } catch (e) {
      print('Failed to fetch items: $e');
    }
    return [];
  }

  Future<List<GroceryList>> fetchListsFromServer(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/lists'),
        headers: await _headers,
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroceryList(
          id: json['id'],
          name: json['name'],
          groupId: json['GroupId'] ?? groupId,
          createdAt: DateTime.parse(json['createdAt']),
          isArchived: json['isArchived'] ?? false,
        )).toList();
      }
    } catch (e) {
      print('Failed to fetch lists: $e');
    }
    return [];
  }

  Future<void> createGroupOnServer(GroceryGroup group) async {
    try {
      // We use 'await _headers' to include the email for the ownership logic
      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: await _headers,
        body: jsonEncode({
          'id': group.id,
          'name': group.name,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Group ${group.name} synced to server successfully.');
      } else {
        debugPrint('Failed to sync group. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error creating group on server: $e');
    }
  }

  // --- LIST SYNC ---

  Future<void> createListOnServer(GroceryList list) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lists'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': list.id,
          'name': list.name,
          'GroupId': list.groupId,
          'createdAt': list.createdAt.toIso8601String(),
        }),
      );
      if (response.statusCode != 201) print('List sync failed: ${response.body}');
    } catch (e) {
      print('Network error creating list: $e');
    }
  }

  Future<void> archiveListOnServer(String listId) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/lists/$listId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isArchived': true}),
      );
    } catch (e) {
      print('Archive sync error: $e');
    }
  }

  // --- ITEM SYNC ---

  Future<void> addItemOnServer(GroceryItem item) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': item.name,
          'status': item.status.name,
          'listId': item.listId,
          'groupId': item.groupId,
          'createdAt': item.createdAt.toIso8601String(),
        }),
      );
    } catch (e) {
      print('Item sync error: $e');
    }
  }

  Future<void> updateItemOnServer(GroceryItem item) async {
    try {
      // Assuming your backend uses the combination of name and listId to find the item
      // or you've added a unique ID to the Item model.
      await http.put(
        Uri.parse('$baseUrl/items/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': item.name,
          'listId': item.listId,
          'status': item.status.name,
        }),
      );
    } catch (e) {
      print('Status update sync error: $e');
    }
  }

  Future<void> deleteItemOnServer(String name, String listId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'listId': listId,
        }),
      );
    } catch (e) {
      print('Delete sync error: $e');
    }
  }
}