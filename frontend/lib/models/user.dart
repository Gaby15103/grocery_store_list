class User {
  final String email;
  final String firstName;
  final String lastName;
  final List<String> authorizedDevices;
  final bool isCurrentDeviceVerified;

  User({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.authorizedDevices,
    required this.isCurrentDeviceVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      authorizedDevices: List<String>.from(json['authorizedDevices'] ?? []),
      isCurrentDeviceVerified: json['isCurrentDeviceVerified'] ?? false,
    );
  }
}