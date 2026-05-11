import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  List<dynamic> _pendingInvites = [];
  List<dynamic> get pendingInvites => _pendingInvites;

  List<String> _recentContacts = [];
  List<String> get recentContacts => _recentContacts;

  User? _userProfile;
  User? get userProfile => _userProfile;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String get syncCode => repository.getSyncCode();


  AuthController({required this.repository}) {
    _isLoggedIn = repository.isLoggedIn();
    if (_isLoggedIn) {
      loadProfile();
    }
  }

  Future<void> loadProfile() async {
    try {
      _userProfile = await repository.fetchProfile();
      notifyListeners();
    } catch (e) {
      debugPrint("Could not fetch user profile: $e");
    }
  }

  Future<void> register(String fName, String lName, String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      await repository.registerUser(fName, lName, email);
      _isLoggedIn = true;
      await loadProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      await loadProfile();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> linkWithCode(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      await repository.linkAccount(code);
      _isLoggedIn = true;
      await loadProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncTokenWithServer() async {
    final email = repository.getEmail();
    if (email == null) return; // Not "logged in" yet

    try {
      final fcm = FirebaseMessaging.instance;
      String? token = await fcm.getToken();

      if (token != null) {
        // This is where it actually hits your DB
        await repository.saveToken(token);
        debugPrint("✅ FCM Token synced to DB for $email");
      }
    } catch (e) {
      debugPrint("❌ Token sync failed: $e");
    }
  }

  Future<void> refreshSocialData() async {
    try {
      _pendingInvites = await repository.getInvites();
      _recentContacts = await repository.getContacts();
      notifyListeners();
    } catch (e) {
      debugPrint("Social sync failed: $e");
    }
  }

  Future<void> sendInvitation(String groupId, String email) async {
    await repository.inviteUser(groupId, email);
    await refreshSocialData(); // Refresh history
  }

  Future<void> acceptGroupInvitation(String groupId) async {
    await repository.acceptInvite(groupId);
    await refreshSocialData();
  }

  Future<void> logout() async {
    await repository.clearAllLocalData();
    notifyListeners();
  }
}