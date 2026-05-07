import 'package:http/http.dart' as http;

import '../../models/group.dart';
import 'base_api.dart';

class GroupApiClient extends BaseApi {

  Future<GroceryGroup> makeGroupPublic(String groupId) async {
    return await request<GroceryGroup>(
      method: 'PUT',
      path: '/groups/$groupId/make-public',
      fromJson: (json) => GroceryGroup.fromJson(json),
    );
  }

  Future<List<GroceryGroup>> fetchGroups() async {
    return await request<List<GroceryGroup>>(
      method: 'GET',
      path: '/groups',
      fromJson: (json) =>
          (json as List).map((g) => GroceryGroup.fromJson(g)).toList(),
    );
  }

  Future<GroceryGroup> fetchGroup(String groupId) async {
    return await request<GroceryGroup>(
      method: 'GET',
      path: '/groups/$groupId',
      fromJson: (json) => GroceryGroup.fromJson(json),
    );
  }

  Future<GroceryGroup> createGroup(String name) async {
    return await request<GroceryGroup>(
      method: 'POST',
      path: '/groups',
      body: {'name': name},
      fromJson: (json) => GroceryGroup.fromJson(json),
    );
  }

  Future<void> deleteGroup(String id) async {
    await request<void>(
      method: 'DELETE',
      path: '/groups/$id',
      fromJson: (json) {},
    );
  }
}
