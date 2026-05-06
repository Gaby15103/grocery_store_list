import 'dart:io';
import '../../models/item.dart';
import 'package:http/http.dart' as http;

import 'base_api.dart';

class ItemApiClient extends BaseApi {

  /// Fetches items from the server
  Future<List<GroceryItem>> fetchItems(String listId) async {
    return await request<List<GroceryItem>>(
      method: 'GET',
      path: '/lists/$listId/items',
      fromJson: (json) => (json as List)
          .map((i) => GroceryItem.fromJson(i))
          .toList(),
    );
  }

  /// Adds an item and returns the one created by the server (with ID)
  Future<GroceryItem> addItem(GroceryItem item) async {
    return await request<GroceryItem>(
      method: 'POST',
      path: '/items',
      body: item.toJson(),
      fromJson: (json) => GroceryItem.fromJson(json),
    );
  }

  /// Updates an item on the server
  Future<void> updateItem(GroceryItem item, String groupId) async {
    final body = item.toJson();
    body['groupId'] = groupId;

    await request<void>(
      method: 'PUT',
      path: '/items/update',
      body: body,
      fromJson: (_) => null,
    );
  }

  /// Deletes an item from the server
  Future<void> deleteItem(int itemId, String name, String listId, String groupId) async {
    await request<void>(
      method: 'DELETE',
      path: '/items/$itemId',
      body: {
        'name': name,
        'listId': listId,
        'groupId': groupId,
      },
      fromJson: (_) => null,
    );
  }

  /// Specialized method for file uploads (handles images for grocery items)
  Future<String?> uploadImage(File file) async {
    final uri = Uri.parse('$baseUrl/upload');

    try {
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll(await headers);

      request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return handleResponse<String?>(
          response,
              (json) => json['path'] as String?
      );

    } on SocketException {
      throw Exception("Network error: Could not upload image to the server.");
    } catch (e) {
      rethrow;
    }
  }
}