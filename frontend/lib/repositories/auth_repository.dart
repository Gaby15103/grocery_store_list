import 'package:hive/hive.dart';
import '../models/group.dart';
import '../models/group_list.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../services/api/auth_api_client.dart';
import '../utils.dart';

class AuthRepository {
  final AuthApiClient _api;
  final Box<String> _metaBox = Hive.box<String>('metadata');
  final Utils _utils = Utils();

  AuthRepository(this._api);

  bool isLoggedIn() => _metaBox.containsKey('userEmail');

  String? getEmail() => _metaBox.get('userEmail');

  String getSyncCode() {
    final box = Hive.box<String>('metadata');
    return box.get('deviceId') ?? "Not Generated";
  }

  /// 1. Registration Flow
  Future<void> registerUser(String first, String last, String email) async {
    final deviceId = await _utils.getUniqueDeviceId();

    await _api.register(
      firstName: first,
      lastName: last,
      email: email,
      deviceId: deviceId,
    );

    await _metaBox.put('firstName', first);
    await _metaBox.put('lastName', last);
    await _metaBox.put('userEmail', email);
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _api.updateProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );

    final box = Hive.box<String>('metadata');
    await box.put('firstName', firstName);
    await box.put('lastName', lastName);
    await box.put('userEmail', email);
  }

  /// 2. Device Linking Flow
  Future<void> linkAccount(String syncCode) async {
    final deviceId = await _utils.getUniqueDeviceId();
    final userData = await _api.linkDevices(deviceId, syncCode);

    await _metaBox.put('userEmail', userData['email']);
    await _metaBox.put('firstName', userData['firstName']);
    await _metaBox.put('lastName', userData['lastName']);
  }

  Future<void> clearAllLocalData() async {
    await Hive.box<GroceryItem>('items').clear();
    await Hive.box<GroceryGroup>('groups').clear();
    await Hive.box<GroceryList>('lists').clear();
    await _metaBox.clear();
  }

  Future<User> fetchProfile() async => await _api.getMe();

  String getDeviceId() => _metaBox.get('deviceId') ?? "Not Generated";

  Future<List<dynamic>> getInvites() => _api.fetchPendingInvites();

  Future<void> acceptInvite(String groupId) => _api.respondToInvite(groupId, 'accepted');

  Future<void> inviteUser(String groupId, String email) => _api.sendInvite(groupId, email);

  Future<List<String>> getContacts() => _api.fetchRecentContacts();
}