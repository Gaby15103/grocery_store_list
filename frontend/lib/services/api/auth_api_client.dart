import '../../models/user.dart';
import 'base_api.dart';

class AuthApiClient extends BaseApi {

  /// GET current user profile
  Future<User> getMe() async {
    return await request<User>(
      method: 'GET',
      path: '/users/me',
      fromJson: (json) => User.fromJson(json),
    );
  }

  /// POST register new user
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String deviceId,
  }) async {
    await request<void>(
      method: 'POST',
      path: '/users/register',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'deviceId': deviceId,
      },
      fromJson: (_) {},
    );
  }

  /// PUT: Update the user's profile details
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await request<void>(
      method: 'PUT',
      path: '/users/profile',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
      },
      fromJson: (_) {},
    );
  }

  /// POST link devices via sync code
  Future<Map<String, dynamic>> linkDevices(String currentDeviceId, String targetCode) async {
    return await request<Map<String, dynamic>>(
      method: 'POST',
      path: '/users/link',
      body: {
        'currentDeviceId': currentDeviceId,
        'targetSyncCode': targetCode,
      },
      fromJson: (json) => json['user'],
    );
  }

  /// GET: Fetch pending invites for the logged-in user
  Future<List<dynamic>> fetchPendingInvites() async {
    return await request<List<dynamic>>(
      method: 'GET',
      path: '/users/invitations',
      fromJson: (json) => json as List<dynamic>,
    );
  }

  /// PUT: Respond to a group invite
  Future<void> respondToInvite(String groupId, String status) async {
    await request<void>(
      method: 'PUT',
      path: '/groups/$groupId/invite/respond',
      body: {'status': status},
      fromJson: (_) {},
    );
  }

  /// POST: Send an invite to another user
  Future<void> sendInvite(String groupId, String targetEmail) async {
    await request<void>(
      method: 'POST',
      path: '/groups/$groupId/invite',
      body: {'email': targetEmail},
      fromJson: (_) {},
    );
  }

  /// GET: Fetch recently invited emails for auto-complete
  Future<List<String>> fetchRecentContacts() async {
    return await request<List<String>>(
      method: 'GET',
      path: '/users/contacts',
      fromJson: (json) => (json as List).map((u) => u['email'] as String).toList(),
    );
  }

  Future<void> updateFcmToken(String  token) async {
    await request<void>(
      method: 'PATCH',
      path: '/users/me/fcm-token',
      body: {'token': token},
      fromJson: (_) {},
    );
  }
}