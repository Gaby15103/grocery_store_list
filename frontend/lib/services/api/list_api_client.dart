import '../../models/group_list.dart';
import 'base_api.dart';

class ListApiClient extends BaseApi {

  Future<List<GroceryList>> fetchLists(String groupId) async {
    return await request<List<GroceryList>>(
      method: 'GET',
      path: '/groups/$groupId/lists',
      fromJson: (json) => (json as List)
          .map((l) => GroceryList.fromJson(l))
          .toList(),
    );
  }

  Future<GroceryList> createList(String name, String groupId) async {
    return await request<GroceryList>(
      method: 'POST',
      path: '/lists',
      body: {
        'name': name,
        'GroupId': groupId,
      },
      fromJson: (json) => GroceryList.fromJson(json),
    );
  }

  Future<void> deleteList(String listId) async {
    return await request<void>(
      method: 'DELETE',
      path: '/lists/$listId',
      fromJson: (_) {},
    );
  }

  Future<GroceryList> archiveList(String listId, String newName) async {
    return await request<GroceryList>(
      method: 'POST',
      path: '/lists/$listId/archive',
      body: {'newName': newName},
      fromJson: (json) => GroceryList.fromJson(json),
    );
  }
}