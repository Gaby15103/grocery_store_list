import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/group.dart';

class SyncService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  // --- GROUP SYNC ---

  Future<void> createGroupOnServer(GroceryGroup group) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': group.id,
          'name': group.name,
        }),
      );
    } catch (e) {
      print('Group sync error: $e');
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