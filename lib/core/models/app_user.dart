class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;

  String get fullName {
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    return name.isEmpty ? username : name;
  }

  Map<String, String> toStorageMap() {
    return {
      'id': id.toString(),
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
    };
  }

  factory AppUser.fromStorageMap(Map<String, String> values) {
    return AppUser(
      id: int.tryParse(values['id'] ?? '') ?? 0,
      username: values['username'] ?? '',
      email: values['email'] ?? '',
      firstName: values['first_name'] ?? '',
      lastName: values['last_name'] ?? '',
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
    );
  }
}
