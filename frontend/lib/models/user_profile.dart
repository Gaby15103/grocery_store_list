class UserProfile {
  final String email;
  final String firstName;
  final String lastName;

  UserProfile({
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
    );
  }
}